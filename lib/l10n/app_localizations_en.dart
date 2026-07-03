// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'Fufaji Online';

  @override
  String get home => 'Home';

  @override
  String get cart => 'Cart';

  @override
  String get profile => 'Profile';

  @override
  String get orders => 'Orders';

  @override
  String get wallet => 'Wallet';

  @override
  String get language => 'Language';

  @override
  String get selectLanguage => 'Select Language';

  @override
  String get searchProducts => 'Search products...';

  @override
  String get category => 'Category';

  @override
  String get addToCart => 'Add to Cart';

  @override
  String get checkout => 'Checkout';

  @override
  String get total => 'Total';

  @override
  String get subtotal => 'Subtotal';

  @override
  String get tax => 'Tax (GST)';

  @override
  String get discount => 'Discount';

  @override
  String get deliveryFee => 'Delivery Fee';

  @override
  String get payNow => 'Pay Now';

  @override
  String get placeOrder => 'Place Order';

  @override
  String get orderStatus => 'Order Status';

  @override
  String get settings => 'Settings';

  @override
  String get offlineMode => 'Offline Mode';

  @override
  String get retry => 'Retry';

  @override
  String get rewards => 'Rewards';

  @override
  String get balance => 'Balance';

  @override
  String get cashback => 'Cashback';

  @override
  String get points => 'Points';

  @override
  String get noInternet => 'No internet connection. You are browsing offline.';

  @override
  String get delivery => 'Delivery';

  @override
  String get employee => 'Employee';

  @override
  String get owner => 'Owner';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get inventory => 'Inventory';

  @override
  String get products => 'Products';

  @override
  String get sales => 'Sales';

  @override
  String get analytics => 'Analytics';

  @override
  String get packOrders => 'Pack Orders';

  @override
  String get startDelivery => 'Start Delivery';

  @override
  String get markDelivered => 'Mark Delivered';

  @override
  String get lowStock => 'Low Stock';

  @override
  String get outOfStock => 'Out of Stock';

  @override
  String get confirmed => 'Confirmed';

  @override
  String get processing => 'Processing';

  @override
  String get packed => 'Packed';

  @override
  String get outForDelivery => 'Out for Delivery';

  @override
  String get delivered => 'Delivered';

  @override
  String get cancelled => 'Cancelled';

  @override
  String get returns => 'Returns';

  @override
  String get attendance => 'Attendance';

  @override
  String get scan => 'Scan';

  @override
  String get voice => 'Voice';

  @override
  String get help => 'Help';

  @override
  String get logout => 'Logout';

  @override
  String get cash => 'Cash';

  @override
  String get upi => 'UPI';

  @override
  String get split => 'Split Payment';

  @override
  String get card => 'Card';

  @override
  String get change => 'Change';

  @override
  String get insufficient => 'Insufficient';

  @override
  String get confirm => 'Confirm';

  @override
  String get cancel => 'Cancel';

  @override
  String get apply => 'Apply';

  @override
  String get managerPin => 'Manager PIN';

  @override
  String get invalidPin => 'Invalid PIN!';

  @override
  String get linkCustomer => 'Link Customer';

  @override
  String get riderCashLimit => 'Rider Cash Limit';

  @override
  String get settleCash => 'Settle Cash';

  @override
  String get pendingSettlement => 'Pending Settlement';

  @override
  String get approved => 'Approved';

  @override
  String get rejected => 'Rejected';

  @override
  String get reason => 'Reason';

  @override
  String get inStock => 'In Stock';

  @override
  String onlyLeft(Object count) {
    return 'Only $count left';
  }

  @override
  String get weight => 'Weight';

  @override
  String get quantity => 'Quantity';

  @override
  String get price => 'Price';

  @override
  String get mrp => 'MRP';

  @override
  String get aisle => 'Aisle';

  @override
  String get shelf => 'Shelf';

  @override
  String get batch => 'Batch';

  @override
  String get expiry => 'Expiry';

  @override
  String get revenue => 'Revenue';

  @override
  String get profit => 'Profit';

  @override
  String get growth => 'Growth';

  @override
  String get topSelling => 'Top Selling';

  @override
  String get recentActivity => 'Recent Activity';

  @override
  String get stepPhone => 'Phone';

  @override
  String get stepCart => 'Cart';

  @override
  String get stepAddress => 'Address';

  @override
  String get stepPayment => 'Payment';

  @override
  String get stepDone => 'Done';

  @override
  String get verifyPhone => 'Verify Phone';

  @override
  String get confirmDeliveryInfo => 'Confirm your delivery information';

  @override
  String get phoneNumber => 'Phone Number';

  @override
  String get enterPhoneHint => 'Enter 10-digit phone number';

  @override
  String get sendOtp => 'Send OTP';

  @override
  String get enterOtp => 'Enter OTP';

  @override
  String enterOtpSentTo(Object phone) {
    return 'Enter OTP sent to +91-$phone';
  }

  @override
  String get otpHint => '6-digit OTP';

  @override
  String get verifyOtp => 'Verify OTP';

  @override
  String get verifyContinue => 'Verify & Continue';

  @override
  String get resendOtp => 'Didn\'t receive OTP? Resend';

  @override
  String get invalidPhoneError => 'Enter a valid 10-digit phone number';

  @override
  String tooManyAttempts(Object minutes) {
    return 'Too many attempts. Try again in $minutes minutes.';
  }

  @override
  String get invalidOtpError => 'Enter a valid 6-digit OTP';

  @override
  String get invalidOtp => 'Invalid OTP';

  @override
  String get reviewOrder => 'Review Your Order';

  @override
  String get items => 'Items';

  @override
  String get enterPromoCode => 'Enter promo code';

  @override
  String get promoApplied => 'Promo code applied!';

  @override
  String get promoInvalid => 'Invalid promo code';

  @override
  String get deliveryFree => 'FREE';

  @override
  String get continueToAddress => 'Continue to Address';

  @override
  String get deliveryAddress => 'Delivery Address';

  @override
  String get deliveryInstructionsHint => 'Delivery instructions (optional)';

  @override
  String get deliveryType => 'Delivery Type';

  @override
  String get continueToPayment => 'Continue to Payment';

  @override
  String get selectDeliveryDateTime => 'Select Delivery Date & Time';

  @override
  String get pleaseSelectAddress => 'Please select a delivery address';

  @override
  String get choosePaymentMethod => 'Choose Payment Method';

  @override
  String get cod => 'Cash on Delivery (COD)';

  @override
  String get codSubtitle => 'Pay when order arrives';

  @override
  String get upiSubtitle => 'Fast & secure payment';

  @override
  String get myWallet => 'My Wallet';

  @override
  String walletAvailable(Object amount) {
    return '₹$amount available';
  }

  @override
  String walletBalanceRemaining(Object amount) {
    return 'Remaining ₹$amount will be paid via COD';
  }

  @override
  String walletBalanceHeader(Object balance, Object total) {
    return 'Wallet Balance: ₹$balance / ₹$total';
  }

  @override
  String get processingPayment => 'Processing payment...';

  @override
  String get cancelOrder => 'Cancel Order';

  @override
  String get orderConfirmed => 'Order Confirmed!';

  @override
  String orderNumberLabel(Object number) {
    return 'Order #$number';
  }

  @override
  String get estimatedDelivery => 'Estimated Delivery';

  @override
  String get trackOrder => 'Track Order';

  @override
  String get continueShopping => 'Continue Shopping';

  @override
  String get paymentFailed => 'Payment Failed';

  @override
  String get paymentFailedMessage => 'Your payment could not be processed';

  @override
  String get retryPayment => 'Retry Payment';

  @override
  String get severeWeatherAlert => 'Severe Weather Alert';

  @override
  String get weatherAdvisory => 'Weather Advisory';

  @override
  String get fastest => 'FASTEST';

  @override
  String get quickBook => 'QUICK BOOK';

  @override
  String get sourcingLocation => 'Sourcing Location';

  @override
  String get farmerPartner => 'Local Farmer Partner';

  @override
  String get localSource => 'Local Source';

  @override
  String get certifiedOrganic => 'Certified Organic';

  @override
  String harvestedOn(Object date) {
    return 'Harvested on: $date';
  }

  @override
  String get freshnessVerified => 'Freshness Verified';

  @override
  String sourcingTransparency(Object source) {
    return 'This product is sourced directly from $source. Scan QR code for full traceability.';
  }

  @override
  String get getDirections => 'Get Directions';

  @override
  String get off => 'OFF';

  @override
  String get fixedPrice => 'Fixed Price';

  @override
  String get add => 'ADD';

  @override
  String get expiringSoon => 'Expiring Soon';

  @override
  String get only => 'Only';

  @override
  String get left => 'left';

  @override
  String get myOrders => 'My Orders';

  @override
  String get tabAll => 'All';

  @override
  String get tabActive => 'Active';

  @override
  String get tabCompleted => 'Completed';

  @override
  String get tabCancelled => 'Cancelled';

  @override
  String get noOrdersYet => 'No orders yet';

  @override
  String get startShoppingSubtitle => 'You haven\'t placed any orders yet. Start shopping now!';

  @override
  String get startShopping => 'Start Shopping';

  @override
  String get order => 'Order';

  @override
  String get moreItems => 'more items';

  @override
  String get totalAmount => 'Total Amount';

  @override
  String get reorder => 'Reorder';

  @override
  String get claim => 'Claim';

  @override
  String get track => 'Track';

  @override
  String get details => 'Details';

  @override
  String todayAt(Object time) {
    return 'Today at $time';
  }

  @override
  String get yesterday => 'Yesterday';

  @override
  String daysAgo(Object count) {
    return '$count days ago';
  }

  @override
  String get rewardWon => 'YOU WON CASHBACK!';

  @override
  String get creditedToWallet => 'Credited to Wallet';

  @override
  String congratsCashback(Object amount) {
    return 'Congratulations! ₹$amount cashback added to your wallet!';
  }

  @override
  String get viewCart => 'VIEW CART';

  @override
  String unavailableItems(Object items) {
    return 'Unavailable: $items';
  }

  @override
  String pricesUpdated(Object count) {
    return 'Prices updated for: $count items';
  }

  @override
  String get statusPending => 'Pending';

  @override
  String get statusConfirmed => 'Confirmed';

  @override
  String get statusProcessing => 'Processing';

  @override
  String get statusPacked => 'Packed';

  @override
  String get statusOutForDelivery => 'Out for Delivery';

  @override
  String get statusDelivered => 'Delivered';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get statusReturned => 'Returned';

  @override
  String get statusRefunded => 'Refunded';

  @override
  String get orderNotFound => 'Order not found';

  @override
  String get downloadInvoice => 'Download Invoice';

  @override
  String get switchCodToOnline => 'Switch from COD to Online Payment';

  @override
  String get openingPaymentGateway => 'Opening secure payment gateway...';

  @override
  String get shop => 'Shop';

  @override
  String get returnOrder => 'Return Order';

  @override
  String get contactSupport => 'Contact Support';

  @override
  String get cancelConfirmMessage => 'Are you sure you want to cancel this order?';

  @override
  String get no => 'No';

  @override
  String get yesCancel => 'Yes, Cancel';

  @override
  String get enterReturnReason => 'Enter reason for return';

  @override
  String get orderCancelled => 'Order Cancelled';

  @override
  String get returnRequested => 'Return Requested';

  @override
  String get trustQualityProofs => 'Trust & Quality Proofs';

  @override
  String get ourTeam => 'Our Team';

  @override
  String get time => 'Time';

  @override
  String packedBy(Object name) {
    return 'Packed with care by $name';
  }

  @override
  String get viewPhotoProof => 'View Photo Proof';

  @override
  String get realWeightGuarantee => 'Real Weight Guarantee';

  @override
  String get perfectWeight => 'Perfect weight';

  @override
  String overPackedMsg(Object diff) {
    return '+${diff}kg free extra!';
  }

  @override
  String underWeightMsg(Object refund) {
    return 'Underweight (₹$refund refunded)';
  }

  @override
  String get ordered => 'Ordered';

  @override
  String get weightProof => 'Weight Proof';

  @override
  String get viewPhoto => 'View Photo';

  @override
  String get labelHome => 'Home';

  @override
  String get labelWork => 'Work';

  @override
  String get labelVillageHome => 'Village Home';

  @override
  String get labelFarm => 'Farm';

  @override
  String get labelOther => 'Other';

  @override
  String get typeHouse => 'House';

  @override
  String get typeApartment => 'Apartment';

  @override
  String get typeShop => 'Shop';

  @override
  String get propertyType => 'Property Type';

  @override
  String get addressType => 'Address Type';

  @override
  String get landmarkLabel => 'Landmark';

  @override
  String get villageColony => 'Village or Colony';

  @override
  String get pinCode => 'PIN Code';

  @override
  String get voiceInstructions => 'Voice Instructions (for Rider)';

  @override
  String get setAsDefault => 'Set as default shipping address';

  @override
  String get savedAddresses => 'Saved Addresses';

  @override
  String get addNew => 'Add New';

  @override
  String get noSavedAddresses => 'No saved addresses';

  @override
  String get noSavedAddressesSubtitle =>
      'You haven\'t saved any addresses yet. Add one to speed up checkout.';

  @override
  String get addShippingAddress => 'Add Shipping Address';

  @override
  String get editAddress => 'Edit Address';

  @override
  String get addNewAddress => 'Add New Address';

  @override
  String get saveAddress => 'Save Address';

  @override
  String get updateAddress => 'Update Address';

  @override
  String get invalidLabel => 'Please specify label';

  @override
  String get invalidAddress => 'Please enter address details';

  @override
  String get invalidVillage => 'Please enter village/colony';

  @override
  String get invalidLandmark => 'Landmark helps rider find you faster';

  @override
  String get invalidPinCode => 'Please enter valid 6-digit PIN code';

  @override
  String get fullAddress => 'House No. / Building / Street';

  @override
  String get recordingStop => 'Recording... Tap to Stop';

  @override
  String get voiceTagAttached => 'Voice Tag Attached ✅';

  @override
  String get recordDirectionHints => 'Record direction hints (e.g. \'Behind the big Banyan tree\')';

  @override
  String get deliveryInstructions => 'Delivery Instructions (Optional)';

  @override
  String get fulfillment => 'Fulfillment';

  @override
  String get packingDashboard => 'Packing Dashboard';

  @override
  String get todaysOrders => 'Today\'s Orders';

  @override
  String get statusNew => 'New';

  @override
  String get packing => 'Packing';

  @override
  String get ready => 'Ready';

  @override
  String get qualityCheck => 'Quality Check';

  @override
  String get quickStats => 'Quick Stats';

  @override
  String get efficiency => 'Efficiency';

  @override
  String get qualityScore => 'Quality Score';

  @override
  String get itemsPacked => 'Items Packed';

  @override
  String get quickActions => 'Quick Actions';

  @override
  String get acceptNewOrder => 'Accept New Order';

  @override
  String get viewPackingQueue => 'View Packing Queue';

  @override
  String get printLabels => 'Print Labels';

  @override
  String get orderQueue => 'Order Queue';

  @override
  String get searchOrderOrCustomer => 'Search order #, customer name';

  @override
  String get sortBy => 'Sort By';

  @override
  String get oldestFirst => 'Oldest First';

  @override
  String get byPriority => 'By Priority';

  @override
  String get highestValue => 'Highest Value';

  @override
  String get customerName => 'Customer Name';

  @override
  String get noOrdersAvailable => 'No orders available';

  @override
  String get packOrder => 'Pack Order';

  @override
  String get customer => 'Customer';

  @override
  String get phone => 'Phone';

  @override
  String get address => 'Address';

  @override
  String get itemsToPack => 'Items to Pack';

  @override
  String get startPacking => 'Start Packing';

  @override
  String get completePacking => 'Complete Packing';

  @override
  String get addSpecialNotes => 'Add any special notes (optional)';

  @override
  String get fragileItemsExample => 'E.g., Fragile items, Handle with care';

  @override
  String get packingStarted => 'Packing started';

  @override
  String get allItemsPacked => 'Please pack all items before completing';

  @override
  String get packingCompleted => 'Packing completed successfully';

  @override
  String get quantityPacked => 'Quantity Packed';

  @override
  String get enterQuantity => 'Enter quantity';

  @override
  String get required => 'Required';

  @override
  String get verifyItems => 'Verify Items';

  @override
  String get rejectionReason => 'Rejection Reason (if rejecting)';

  @override
  String get damageExample => 'E.g., Damaged items, Missing items, Incorrect quantity';

  @override
  String get approveOrder => 'Approve Order';

  @override
  String get rejectOrder => 'Reject Order';

  @override
  String get confirmRejection => 'Confirm Rejection';

  @override
  String get areYouSureReject => 'Are you sure you want to reject this order?';

  @override
  String get orderRejected => 'Order rejected. Sent back for repacking';

  @override
  String get orderApproved => 'Order approved successfully';

  @override
  String get noOrdersReadyQC => 'No orders ready for QC';

  @override
  String get itemsPerMin => 'Items/min';

  @override
  String get verifyBarcode => 'Verify';

  @override
  String get scanBarcode => 'Scan barcode';

  @override
  String get printLabel => 'Print Label';

  @override
  String get labelPrintedSuccess => 'Label printed successfully';

  @override
  String get printFailed => 'Print failed';

  @override
  String orderAssigned(Object id) {
    return 'Order $id accepted';
  }

  @override
  String get created => 'Created';

  @override
  String minutesAgo(Object count) {
    return '$count min ago';
  }

  @override
  String get highPriority => 'HIGH PRIORITY';

  @override
  String get viewAndAccept => 'View and accept pending orders';

  @override
  String get continueWithOrders => 'Continue with assigned orders';

  @override
  String get reviewPackedOrders => 'Review packed orders';

  @override
  String get noOrdersAssigned => 'No orders assigned';

  @override
  String get taskNotFound => 'Task not found';

  @override
  String get loadingTask => 'Loading task...';

  @override
  String get errorLoadingTask => 'Error loading task';

  @override
  String get errorAcceptingOrder => 'Error accepting order';

  @override
  String get errorLoadingOrders => 'Error loading orders';
}
