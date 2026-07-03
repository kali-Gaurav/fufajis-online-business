enum CustomerState { guest, guestWithCart, otpPending, verifiedCustomer, trustedDevice }

extension CustomerStateExtension on CustomerState {
  bool get canBrowseProducts => true;
  bool get canAddToCart =>
      this == CustomerState.guest ||
      this == CustomerState.guestWithCart ||
      this == CustomerState.verifiedCustomer ||
      this == CustomerState.trustedDevice;
  bool get canCheckout =>
      this == CustomerState.verifiedCustomer || this == CustomerState.trustedDevice;
  bool get needsOtpForCheckout =>
      this == CustomerState.guest || this == CustomerState.guestWithCart;
  bool get hasAccount =>
      this == CustomerState.verifiedCustomer || this == CustomerState.trustedDevice;
}
