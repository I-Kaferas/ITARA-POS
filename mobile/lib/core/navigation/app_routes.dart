abstract final class AppRoutes {
  static const adminLogin = '/admin-login';
  static const welcome = '/welcome';
  static const onboarding = '/onboarding';
  static const showcase = '/showcase';
  static const onboardingFinish = '/welcome/start';
  static const setup = '/setup';
  static const slaveSetup = '/setup/slave';
  static const pin = '/pin';
  static const dashboard = '/dashboard';
  static const pos = '/pos';
  static const orders = '/orders';
  static const returns = '/returns';
  static const shifts = '/shifts';
  static const cashRegister = '/cash-register';
  static const reservations = '/reservations';
  static const stock = '/stock';
  static const menu = '/menu';
  static const configuration = '/configuration';
  static const hub = '/hub';
  static const masterConfiguration = '/hub/master';
  static const cashierSettings = '/cashier-settings';
  static const hospitality = '/dashboard/hospitality';
  static const kitchen = '/dashboard/kitchen';
  static const services = '/dashboard/services';
  static const production = '/dashboard/production';
  static const accounting = '/dashboard/accounting';
  static const reports = '/dashboard/reports';
  static const notifications = '/dashboard/notifications';
  static const customerAccount = '/dashboard/customer-account';
  static const expenses = '/dashboard/expenses';
  static const barcode = '/dashboard/barcode';
  static const sync = '/dashboard/sync';

  /// Screens reserved to administrators; the shell hides its navigation on them.
  static bool isConfiguration(String location) =>
      location == configuration ||
      location == hub ||
      location == masterConfiguration ||
      location == cashierSettings;

  static String saleDetail(String id) => '/orders/sale/$id';
  static String shiftDetail(String id) => '/shifts/$id';
}
