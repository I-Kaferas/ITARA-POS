import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/navigation/app_routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_motion.dart';
import 'onboarding_cubit.dart';
import 'onboarding_frame.dart';
import 'onboarding_page.dart';
import 'package:pos_mobile/core/i18n/tr.dart';

class OnboardingScreen extends StatelessWidget {
  const OnboardingScreen({super.key});

  static final pages = [
    OnboardingPageData(
      title: tr('Gestion commerciale'),
      body:
          'Tenez le catalogue, les prix et les stocks au même endroit que les ventes.',
      points: [
        'Produits, catégories, prix et stocks.',
        'Suivi des ventes et des achats.',
        'Vue des performances depuis le tableau de bord.',
      ],
      icon: Icons.storefront_outlined,
      tint: const Color(0xFF2F6F9A),
      visual: OnboardingVisual.commerce,
      eyebrow: '01 · Catalogue',
    ),
    OnboardingPageData(
      title: tr('Point de vente'),
      body:
          'Encaissez vite, même sans réseau, puis synchronisez quand la liaison revient.',
      points: [
        'Caisse, commandes, paiements et reçus.',
        'Plusieurs caisses et imprimantes.',
        'Vente hors ligne déjà prévue sur ce terminal.',
      ],
      icon: Icons.point_of_sale_outlined,
      tint: const Color(0xFF0F7A4D),
      visual: OnboardingVisual.pos,
      eyebrow: '02 · Caisse',
    ),
    OnboardingPageData(
      title: tr('Restaurant et hôtel'),
      body:
          'Les tables, la cuisine et les séjours utilisent les mêmes commandes que la caisse.',
      points: [
        'Tables, commandes et envoi en cuisine.',
        'Consommations liées au séjour.',
        'Report sur le folio du client, déjà géré par l’hôtellerie.',
      ],
      icon: Icons.restaurant_outlined,
      tint: const Color(0xFFB86E09),
      visual: OnboardingVisual.hospitality,
      eyebrow: '03 · Service',
    ),
    OnboardingPageData(
      title: tr('Contrôle'),
      body:
          'Suivez l’activité, les dépenses et les accès sans quitter le terminal.',
      points: [
        'Rapports et statistiques.',
        'Dépenses et achats.',
        'Caissiers, rôles du terminal et permissions déjà en place.',
      ],
      icon: Icons.insights_outlined,
      tint: const Color(0xFF12243C),
      visual: OnboardingVisual.control,
      eyebrow: '04 · Pilotage',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => OnboardingCubit(length: pages.length),
      child: const _OnboardingBody(),
    );
  }
}

class _OnboardingBody extends StatefulWidget {
  const _OnboardingBody();

  @override
  State<_OnboardingBody> createState() => _OnboardingBodyState();
}

class _OnboardingBodyState extends State<_OnboardingBody> {
  final _controller = PageController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _animateTo(int index) {
    final cubit = context.read<OnboardingCubit>();
    cubit.go(index);
    if (!AppMotion.reduceMotion(context)) {
      _controller.animateToPage(
        cubit.state.index,
        duration: AppMotion.navigation,
        curve: AppMotion.standard,
      );
    } else {
      _controller.jumpToPage(cubit.state.index);
    }
  }

  String _path(String route) {
    final replay =
        GoRouterState.of(context).uri.queryParameters['replay'] == '1';
    return replay ? '$route?replay=1' : route;
  }

  @override
  Widget build(BuildContext context) {
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.arrowRight): () {
          final cubit = context.read<OnboardingCubit>();
          if (cubit.isLast) {
            context.go(_path(AppRoutes.showcase));
          } else {
            _animateTo(cubit.state.index + 1);
          }
        },
        const SingleActivator(LogicalKeyboardKey.arrowLeft): () {
          final cubit = context.read<OnboardingCubit>();
          if (!cubit.isFirst) _animateTo(cubit.state.index - 1);
        },
      },
      child: Focus(
        autofocus: true,
        child: BlocBuilder<OnboardingCubit, OnboardingStep>(
          builder: (context, step) {
            return OnboardingFrame(
              footer: _Footer(
                index: step.index,
                length: OnboardingScreen.pages.length,
                onPrevious: step.index == 0
                    ? null
                    : () => _animateTo(step.index - 1),
                onNext: () {
                  if (step.index == OnboardingScreen.pages.length - 1) {
                    context.go(_path(AppRoutes.showcase));
                  } else {
                    _animateTo(step.index + 1);
                  }
                },
                onSkip: () => context.go(_path(AppRoutes.onboardingFinish)),
              ),
              child: PageView.builder(
                controller: _controller,
                itemCount: OnboardingScreen.pages.length,
                onPageChanged: context.read<OnboardingCubit>().go,
                itemBuilder: (context, index) =>
                    OnboardingPage(data: OnboardingScreen.pages[index]),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({
    required this.index,
    required this.length,
    required this.onPrevious,
    required this.onNext,
    required this.onSkip,
  });

  final int index;
  final int length;
  final VoidCallback? onPrevious;
  final VoidCallback onNext;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Semantics(
          label: trf('Étape {0} sur {1}', [index + 1, length]),
          child: Row(
            children: [
              for (var i = 0; i < length; i++)
                Expanded(
                  child: AnimatedContainer(
                    duration: AppMotion.fast,
                    height: 4,
                    margin: EdgeInsets.only(right: i == length - 1 ? 0 : 6),
                    decoration: BoxDecoration(
                      color: i <= index
                          ? AppColors.brand600
                          : AppColors.borderStrong,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            TextButton(
              onPressed: onSkip,
              child: Text(
                tr('Ignorer'),
                style: GoogleFonts.ibmPlexSans(
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: 140,
              child: OnboardingButton(
                label: tr('Précédent'),
                onPressed: onPrevious,
              ),
            ),
            const SizedBox(width: 10),
            SizedBox(
              width: 148,
              child: OnboardingButton(
                label: index == length - 1 ? 'Continuer' : 'Suivant',
                primary: true,
                onPressed: onNext,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
