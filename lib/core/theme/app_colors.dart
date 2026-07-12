import 'package:flutter/material.dart';
import '../constants/app_constants.dart';

class AppColors {
  // Brand Colors
  static const Color primary = Color(0xFF6C63FF);
  static const Color primaryDark = Color(0xFF5A52E0);
  static const Color primaryLight = Color(0xFF8B85FF);
  static const Color secondary = Color(0xFF00D4AA);
  static const Color accent = Color(0xFFFF6B6B);
  static const Color warning = Color(0xFFFFB347);
  static const Color info = Color(0xFF4FC3F7);
  static const Color success = Color(0xFF66BB6A);
  static const Color error = Color(0xFFEF5350);

  // Light Theme
  static const Color lightBackground = Color(0xFFF8F9FF);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightCard = Color(0xFFFFFFFF);
  static const Color lightBorder = Color(0xFFE8EAF6);
  static const Color lightText = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6B7280);
  static const Color lightDivider = Color(0xFFEEF0F8);

  // Dark Theme
  static const Color darkBackground = Color(0xFF0F0E17);
  static const Color darkSurface = Color(0xFF1A1A2E);
  static const Color darkCard = Color(0xFF16213E);
  static const Color darkBorder = Color(0xFF2D2D4E);
  static const Color darkText = Color(0xFFF1F1F1);
  static const Color darkTextSecondary = Color(0xFF9CA3AF);
  static const Color darkDivider = Color(0xFF2A2A3E);

  // Status Colors
  static const Color statusNew = Color(0xFF4FC3F7);
  static const Color statusWaitingInspection = Color(0xFF29B6F6);
  static const Color statusInspecting = Color(0xFFFFB347);
  static const Color statusFaultIdentified = Color(0xFF7E57C2);
  static const Color statusWaitingCustomerApproval = Color(0xFFFFA726);
  static const Color statusCustomerApproved = Color(0xFF43A047);
  static const Color statusCustomerRejected = Color(0xFFE53935);
  static const Color statusWaitingPart = Color(0xFFFF7043);
  static const Color statusRepairing = Color(0xFF9C27B0);
  static const Color statusUnderTesting = Color(0xFF00897B);
  static const Color statusRepaired = Color(0xFF26C6DA);
  static const Color statusReady = Color(0xFF66BB6A);
  static const Color statusDelivered = Color(0xFF78909C);
  static const Color statusUnrepairable = Color(0xFF5D6D7E);
  static const Color statusCancelled = Color(0xFFEF5350);
  static const Color statusWarrantyReturn = Color(0xFF5C6BC0);
  static const Color statusAbandoned = Color(0xFFD84315);

  static Color maintenanceStatus(String status) {
    switch (status) {
      case AppConstants.statusNew:
        return statusNew;
      case AppConstants.statusWaitingInspection:
        return statusWaitingInspection;
      case AppConstants.statusInspecting:
        return statusInspecting;
      case AppConstants.statusFaultIdentified:
        return statusFaultIdentified;
      case AppConstants.statusWaitingCustomerApproval:
        return statusWaitingCustomerApproval;
      case AppConstants.statusCustomerApproved:
        return statusCustomerApproved;
      case AppConstants.statusCustomerRejected:
        return statusCustomerRejected;
      case AppConstants.statusWaitingPart:
        return statusWaitingPart;
      case AppConstants.statusRepairing:
        return statusRepairing;
      case AppConstants.statusUnderTesting:
        return statusUnderTesting;
      case AppConstants.statusRepaired:
        return statusRepaired;
      case AppConstants.statusReady:
        return statusReady;
      case AppConstants.statusDelivered:
        return statusDelivered;
      case AppConstants.statusUnrepairable:
        return statusUnrepairable;
      case AppConstants.statusCancelled:
        return statusCancelled;
      case AppConstants.statusWarrantyReturn:
        return statusWarrantyReturn;
      case AppConstants.statusAbandoned:
        return statusAbandoned;
      default:
        return primary;
    }
  }

  // Warranty Colors
  static const Color warrantyActive = Color(0xFF66BB6A);
  static const Color warrantyExpiringSoon = Color(0xFFFFB347);
  static const Color warrantyExpired = Color(0xFFEF5350);

  // Gradient
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4FC3F7)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient darkGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF9C88FF)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient successGradient = LinearGradient(
    colors: [Color(0xFF66BB6A), Color(0xFF43A047)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient warningGradient = LinearGradient(
    colors: [Color(0xFFFFB347), Color(0xFFFF8C00)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFEF5350), Color(0xFFE53935)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient infoGradient = LinearGradient(
    colors: [Color(0xFF4FC3F7), Color(0xFF0288D1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const LinearGradient tealGradient = LinearGradient(
    colors: [Color(0xFF00D4AA), Color(0xFF00897B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
