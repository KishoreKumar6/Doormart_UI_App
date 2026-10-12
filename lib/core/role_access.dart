import 'constants.dart';

class RoleAccess {
  static const _customerOnlyRoutes = {
    '/',
    '/cart',
    '/checkout',
    '/address',
    '/address/edit',
    '/payment',
    '/order-success',
    '/live-order-tracking',
    '/my-orders',
    '/order-details',
    '/scheduled-orders',
    '/wishlist',
    '/notifications',
    '/profile',
    '/profile/edit',
    '/settings',
  };

  static bool canAccessRoute(String? role, String routeName) {
    if (routeName == '/login' ||
        routeName == '/signup' ||
        routeName == '/splash' ||
        routeName == '/vendor/login' ||
        routeName == '/vendor/register' ||
        routeName == '/vendor/register-success' ||
        routeName == '/vendor/status' ||
        routeName == '/delivery/register' ||
        routeName == '/delivery/status' ||
        routeName == '/delivery/payment') {
      return true;
    }
    if (routeName.startsWith('/vendor')) {
      if (routeName == '/vendor/dashboard') {
        return role == UserRoles.vendor ||
            role == UserRoles.admin ||
            role == UserRoles.superAdmin;
      }
      return role == UserRoles.vendor;
    }
    if (routeName.startsWith('/super-admin')) {
      return role == UserRoles.superAdmin || routeName == '/super-admin/login';
    }
    if (routeName.startsWith('/admin')) {
      if (routeName == '/admin/users' ||
          routeName == '/admin/banners' ||
          routeName == '/admin/notifications' ||
          routeName == '/admin/help-support' ||
          routeName == '/admin/delivery' ||
          routeName == '/admin/categories') {
        return role == UserRoles.superAdmin || routeName == '/admin/login';
      }
      return role == UserRoles.admin ||
          role == UserRoles.vendor ||
          role == UserRoles.superAdmin ||
          routeName == '/admin/login';
    }
    if (routeName.startsWith('/delivery')) {
      return role == UserRoles.deliveryPerson ||
          routeName == '/delivery/login' ||
          routeName == '/delivery/register' ||
          routeName == '/delivery/status' ||
          routeName == '/delivery/payment';
    }
    if (_customerOnlyRoutes.contains(routeName)) {
      return role == null || role == UserRoles.user;
    }
    return true;
  }

  static String dashboardForRole(String? role) {
    switch (role) {
      case UserRoles.deliveryPerson:
        return '/delivery';
      case UserRoles.vendor:
        return '/vendor/dashboard';
      case UserRoles.admin:
        return '/admin';
      case UserRoles.superAdmin:
        return '/super-admin';
      case UserRoles.user:
      default:
        return '/';
    }
  }
}
