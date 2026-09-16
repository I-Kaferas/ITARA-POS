abstract final class AppRoutes {
  static const adminLogin = '/admin-login';
  static const setup = '/setup';
  static const pin = '/pin';
  static const dashboard = '/dashboard';
  static const pos = '/pos';
  static const orders = '/orders';
  static const returns = '/returns';
  static const shifts = '/shifts';
  static const reservations = '/reservations';
  static const configuration = '/configuration';
  static const hospitality = '/dashboard/hospitality';
  static const services = '/dashboard/services';
  static const production = '/dashboard/production';
  static const accounting = '/dashboard/accounting';
  static const reports = '/dashboard/reports';
  static const notifications = '/dashboard/notifications';
  static const customerAccount = '/dashboard/customer-account';
  static const expenses = '/dashboard/expenses';
  static const barcode = '/dashboard/barcode';
  static const sync = '/dashboard/sync';

  static String saleDetail(String id) => '/orders/sale/$id';
  static String shiftDetail(String id) => '/shifts/$id';
}
