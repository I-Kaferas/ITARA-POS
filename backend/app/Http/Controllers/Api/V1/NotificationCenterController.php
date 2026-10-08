<?php

namespace App\Http\Controllers\Api\V1;

use App\Enums\NotificationChannel;
use App\Enums\NotificationEvent;
use App\Http\Controllers\Controller;
use App\Models\InboxNotification;
use App\Models\NotificationDelivery;
use App\Services\Notifications\ChannelDispatcher;
use App\Services\Notifications\NotificationCenter;
use App\Services\Notifications\NotificationDigest;
use App\Tenancy\TenantCache;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Validation\Rule;

class NotificationCenterController extends Controller
{
    public function __construct(
        private readonly NotificationCenter $center,
        private readonly NotificationDigest $digest,
        private readonly ChannelDispatcher $channels,
    ) {}

    public function index(Request $request): JsonResponse
    {
        if ($request->boolean('refresh')) {
            Cache::forget(app(TenantCache::class)->key('notification-digest'));
        }
        $this->digest->scanIfDue();

        $user = $request->user();
        $query = InboxNotification::query()
            ->where('user_id', $user->id)
            ->latest();

        if ($request->filled('event')) {
            $query->where('event', $request->string('event'));
        }
        if ($request->boolean('unread')) {
            $query->whereNull('read_at');
        }

        $page = $query->paginate($request->pageSize(20));
        $unread = InboxNotification::query()
            ->where('user_id', $user->id)
            ->whereNull('read_at')
            ->count();

        return response()->json([
            'data' => $page->items(),
            'meta' => [
                'unread' => $unread,
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'total' => $page->total(),
                'can_manage' => $this->center->canManage($user),
            ],
        ]);
    }

    public function markRead(Request $request, InboxNotification $inboxNotification): JsonResponse
    {
        $this->authorizeOwn($request, $inboxNotification);
        if ($inboxNotification->read_at === null) {
            $inboxNotification->forceFill(['read_at' => now()])->save();
        }

        return response()->json(['data' => $inboxNotification]);
    }

    public function markAllRead(Request $request): JsonResponse
    {
        InboxNotification::query()
            ->where('user_id', $request->user()->id)
            ->whereNull('read_at')
            ->update(['read_at' => now()]);

        return response()->json(['data' => ['unread' => 0]]);
    }

    public function destroy(Request $request, InboxNotification $inboxNotification): JsonResponse
    {
        $this->authorizeOwn($request, $inboxNotification);
        $inboxNotification->delete();

        return response()->json(status: 204);
    }

    public function preferences(Request $request): JsonResponse
    {
        $scope = $request->string('scope')->toString() ?: 'user';
        if (! in_array($scope, ['user', 'tenant'], true)) {
            $scope = 'user';
        }

        $user = $request->user();

        return response()->json([
            'data' => $this->center->rulesFor($user, $scope),
            'meta' => [
                'scope' => $scope,
                'can_manage' => $this->center->canManage($user),
                'channels' => NotificationChannel::values(),
            ],
        ]);
    }

    public function updatePreferences(Request $request): JsonResponse
    {
        $data = $request->validate([
            'scope' => ['required', Rule::in(['user', 'tenant'])],
            'reset' => ['sometimes', 'boolean'],
            'rules' => ['required_unless:reset,true', 'array'],
            'rules.*.event' => ['required', Rule::in(NotificationEvent::values())],
            'rules.*.channels' => ['array'],
            'rules.*.channels.*' => [Rule::in(NotificationChannel::values())],
        ]);

        $user = $request->user();
        if (($data['reset'] ?? false) === true && $data['scope'] === 'user') {
            $this->center->resetUserRules($user);
        } else {
            $this->center->saveRules($user, $data['scope'], $data['rules'] ?? []);
        }

        return response()->json([
            'data' => $this->center->rulesFor($user, $data['scope']),
        ]);
    }

    public function channels(): JsonResponse
    {
        return response()->json(['data' => $this->channels->describe()]);
    }

    public function updateChannel(Request $request, string $channel): JsonResponse
    {
        $channel = NotificationChannel::tryFrom($channel);
        if ($channel === null) {
            return response()->json(['message' => 'Canal inconnu.'], 404);
        }

        $data = $request->validate([
            'enabled' => ['required', 'boolean'],
            'config' => ['array'],
            'config.endpoint' => ['nullable', 'url', 'max:500'],
            'config.from_address' => ['nullable', 'email', 'max:255'],
            'config.from_name' => ['nullable', 'string', 'max:120'],
            'config.sender' => ['nullable', 'string', 'max:32'],
            'config.api_key' => ['nullable', 'string', 'max:500'],
            'config.phone_number_id' => ['nullable', 'string', 'max:64'],
            'config.access_token' => ['nullable', 'string', 'max:500'],
            'config.server_key' => ['nullable', 'string', 'max:500'],
        ]);

        $this->center->saveChannel($channel, (bool) $data['enabled'], $data['config'] ?? []);

        return response()->json([
            'data' => collect($this->channels->describe())->firstWhere('channel', $channel->value),
        ]);
    }

    public function deliveries(Request $request): JsonResponse
    {
        $query = NotificationDelivery::query()->with('user:id,name,email')->latest();

        if ($request->filled('event')) {
            $query->where('event', $request->string('event'));
        }
        if ($request->filled('channel')) {
            $query->where('channel', $request->string('channel'));
        }
        if ($request->filled('status')) {
            $query->where('status', $request->string('status'));
        }

        $page = $query->paginate($request->pageSize());

        return response()->json([
            'data' => $page->items(),
            'meta' => [
                'current_page' => $page->currentPage(),
                'last_page' => $page->lastPage(),
                'total' => $page->total(),
            ],
        ]);
    }

    public function test(Request $request): JsonResponse
    {
        $data = $request->validate([
            'event' => ['required', Rule::in(NotificationEvent::values())],
            'channel' => ['required', Rule::in(NotificationChannel::values())],
        ]);

        $this->center->sendTest(
            $request->user(),
            NotificationEvent::from($data['event']),
            NotificationChannel::from($data['channel']),
        );

        return response()->json(['data' => ['sent' => true]]);
    }

    public function storePushToken(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
            'platform' => ['required', Rule::in(['web', 'android', 'ios'])],
        ]);

        $subscription = $this->center->registerPushToken($request->user(), $data['token'], $data['platform']);

        return response()->json(['data' => $subscription], 201);
    }

    public function destroyPushToken(Request $request): JsonResponse
    {
        $data = $request->validate([
            'token' => ['required', 'string', 'max:512'],
        ]);
        $this->center->removePushToken($request->user(), $data['token']);

        return response()->json(status: 204);
    }

    private function authorizeOwn(Request $request, InboxNotification $notification): void
    {
        if ($notification->user_id !== $request->user()->id) {
            abort(404);
        }
    }
}
