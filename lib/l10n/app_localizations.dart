import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hi.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('en'), Locale('hi')];

  /// Generic translation method for dynamic keys
  String translate(String key, {Map<String, dynamic>? arguments}) {
    switch (key) {
      case 'appTitle':
        return appTitle;
      case 'home':
        return home;
      case 'cart':
        return cart;
      case 'profile':
        return profile;
      case 'orders':
        return orders;
      case 'wallet':
        return wallet;
      case 'language':
        return language;
      case 'selectLanguage':
        return selectLanguage;
      case 'searchProducts':
        return searchProducts;
      case 'category':
        return category;
      case 'addToCart':
        return addToCart;
      case 'checkout':
        return checkout;
      case 'total':
        return total;
      case 'subtotal':
        return subtotal;
      case 'tax':
        return tax;
      case 'discount':
        return discount;
      case 'deliveryFee':
        return deliveryFee;
      case 'payNow':
        return payNow;
      case 'placeOrder':
        return placeOrder;
      case 'orderStatus':
        return orderStatus;
      case 'settings':
        return settings;
      case 'offlineMode':
        return offlineMode;
      case 'retry':
        return retry;
      case 'rewards':
        return rewards;
      case 'balance':
        return balance;
      case 'cashback':
        return cashback;
      case 'points':
        return points;
      case 'noInternet':
        return noInternet;
      case 'delivery':
        return delivery;
      case 'employee':
        return employee;
      case 'owner':
        return owner;
      case 'dashboard':
        return dashboard;
      case 'inventory':
        return inventory;
      case 'products':
        return products;
      case 'sales':
        return sales;
      case 'analytics':
        return analytics;
      case 'packOrders':
        return packOrders;
      case 'startDelivery':
        return startDelivery;
      case 'markDelivered':
        return markDelivered;
      case 'lowStock':
        return lowStock;
      case 'outOfStock':
        return outOfStock;
      case 'confirmed':
        return confirmed;
      case 'processing':
        return processing;
      case 'packed':
        return packed;
      case 'outForDelivery':
        return outForDelivery;
      case 'delivered':
        return delivered;
      case 'cancelled':
        return cancelled;
      case 'returns':
        return returns;
      case 'attendance':
        return attendance;
      case 'scan':
        return scan;
      case 'voice':
        return voice;
      case 'help':
        return help;
      case 'logout':
        return logout;
      case 'cash':
        return cash;
      case 'upi':
        return upi;
      case 'split':
        return split;
      case 'card':
        return card;
      case 'change':
        return change;
      case 'insufficient':
        return insufficient;
      case 'confirm':
        return confirm;
      case 'cancel':
        return cancel;
      case 'apply':
        return apply;
      case 'managerPin':
        return managerPin;
      case 'invalidPin':
        return invalidPin;
      case 'linkCustomer':
        return linkCustomer;
      case 'riderCashLimit':
        return riderCashLimit;
      case 'settleCash':
        return settleCash;
      case 'pendingSettlement':
        return pendingSettlement;
      case 'approved':
        return approved;
      case 'rejected':
        return rejected;
      case 'reason':
        return reason;
      case 'inStock':
        return inStock;
      case 'onlyLeft':
        return onlyLeft(arguments?['count'] as Object? ?? '');
      case 'weight':
        return weight;
      case 'quantity':
        return quantity;
      case 'price':
        return price;
      case 'mrp':
        return mrp;
      case 'aisle':
        return aisle;
      case 'shelf':
        return shelf;
      case 'batch':
        return batch;
      case 'expiry':
        return expiry;
      case 'revenue':
        return revenue;
      case 'profit':
        return profit;
      case 'growth':
        return growth;
      case 'topSelling':
        return topSelling;
      case 'recentActivity':
        return recentActivity;
      case 'stepPhone':
        return stepPhone;
      case 'stepCart':
        return stepCart;
      case 'stepAddress':
        return stepAddress;
      case 'stepPayment':
        return stepPayment;
      case 'stepDone':
        return stepDone;
      case 'verifyPhone':
        return verifyPhone;
      case 'confirmDeliveryInfo':
        return confirmDeliveryInfo;
      case 'phoneNumber':
        return phoneNumber;
      case 'enterPhoneHint':
        return enterPhoneHint;
      case 'sendOtp':
        return sendOtp;
      case 'enterOtp':
        return enterOtp;
      case 'enterOtpSentTo':
        return enterOtpSentTo(arguments?['phone'] as Object? ?? '');
      case 'otpHint':
        return otpHint;
      case 'verifyOtp':
        return verifyOtp;
      case 'verifyContinue':
        return verifyContinue;
      case 'resendOtp':
        return resendOtp;
      case 'invalidPhoneError':
        return invalidPhoneError;
      case 'tooManyAttempts':
        return tooManyAttempts(arguments?['minutes'] as Object? ?? '');
      case 'invalidOtpError':
        return invalidOtpError;
      case 'invalidOtp':
        return invalidOtp;
      case 'reviewOrder':
        return reviewOrder;
      case 'items':
        return items;
      case 'enterPromoCode':
        return enterPromoCode;
      case 'promoApplied':
        return promoApplied;
      case 'promoInvalid':
        return promoInvalid;
      case 'deliveryFree':
        return deliveryFree;
      case 'continueToAddress':
        return continueToAddress;
      case 'deliveryAddress':
        return deliveryAddress;
      case 'deliveryInstructionsHint':
        return deliveryInstructionsHint;
      case 'deliveryType':
        return deliveryType;
      case 'continueToPayment':
        return continueToPayment;
      case 'selectDeliveryDateTime':
        return selectDeliveryDateTime;
      case 'pleaseSelectAddress':
        return pleaseSelectAddress;
      case 'choosePaymentMethod':
        return choosePaymentMethod;
      case 'cod':
        return cod;
      case 'codSubtitle':
        return codSubtitle;
      case 'upiSubtitle':
        return upiSubtitle;
      case 'myWallet':
        return myWallet;
      case 'walletAvailable':
        return walletAvailable(arguments?['amount'] as Object? ?? '');
      case 'walletBalanceRemaining':
        return walletBalanceRemaining(arguments?['amount'] as Object? ?? '');
      case 'walletBalanceHeader':
        return walletBalanceHeader(
          arguments?['balance'] as Object? ?? '',
          arguments?['total'] as Object? ?? '',
        );
      case 'processingPayment':
        return processingPayment;
      case 'cancelOrder':
        return cancelOrder;
      case 'orderConfirmed':
        return orderConfirmed;
      case 'orderNumberLabel':
        return orderNumberLabel(arguments?['number'] as Object? ?? '');
      case 'estimatedDelivery':
        return estimatedDelivery;
      case 'trackOrder':
        return trackOrder;
      case 'continueShopping':
        return continueShopping;
      case 'paymentFailed':
        return paymentFailed;
      case 'paymentFailedMessage':
        return paymentFailedMessage;
      case 'retryPayment':
        return retryPayment;
      case 'severeWeatherAlert':
        return severeWeatherAlert;
      case 'weatherAdvisory':
        return weatherAdvisory;
      case 'fastest':
        return fastest;
      case 'quickBook':
        return quickBook;
      case 'sourcingLocation':
        return sourcingLocation;
      case 'farmerPartner':
        return farmerPartner;
      case 'localSource':
        return localSource;
      case 'certifiedOrganic':
        return certifiedOrganic;
      case 'harvestedOn':
        return harvestedOn(arguments?['date'] as Object? ?? '');
      case 'freshnessVerified':
        return freshnessVerified;
      case 'sourcingTransparency':
        return sourcingTransparency(arguments?['source'] as Object? ?? '');
      case 'getDirections':
        return getDirections;
      case 'off':
        return off;
      case 'fixedPrice':
        return fixedPrice;
      case 'add':
        return add;
      case 'expiringSoon':
        return expiringSoon;
      case 'only':
        return only;
      case 'left':
        return left;
      case 'myOrders':
        return myOrders;
      case 'tabAll':
        return tabAll;
      case 'tabActive':
        return tabActive;
      case 'tabCompleted':
        return tabCompleted;
      case 'tabCancelled':
        return tabCancelled;
      case 'noOrdersYet':
        return noOrdersYet;
      case 'startShoppingSubtitle':
        return startShoppingSubtitle;
      case 'startShopping':
        return startShopping;
      case 'order':
        return order;
      case 'moreItems':
        return moreItems;
      case 'totalAmount':
        return totalAmount;
      case 'reorder':
        return reorder;
      case 'claim':
        return claim;
      case 'track':
        return track;
      case 'details':
        return details;
      case 'todayAt':
        return todayAt(arguments?['time'] as Object? ?? '');
      case 'yesterday':
        return yesterday;
      case 'daysAgo':
        return daysAgo(arguments?['count'] as Object? ?? '');
      case 'rewardWon':
        return rewardWon;
      case 'creditedToWallet':
        return creditedToWallet;
      case 'congratsCashback':
        return congratsCashback(arguments?['amount'] as Object? ?? '');
      case 'viewCart':
        return viewCart;
      case 'unavailableItems':
        return unavailableItems(arguments?['items'] as Object? ?? '');
      case 'pricesUpdated':
        return pricesUpdated(arguments?['count'] as Object? ?? '');
      case 'statusPending':
        return statusPending;
      case 'statusConfirmed':
        return statusConfirmed;
      case 'statusProcessing':
        return statusProcessing;
      case 'statusPacked':
        return statusPacked;
      case 'statusOutForDelivery':
        return statusOutForDelivery;
      case 'statusDelivered':
        return statusDelivered;
      case 'statusCancelled':
        return statusCancelled;
      case 'statusReturned':
        return statusReturned;
      case 'statusRefunded':
        return statusRefunded;
      case 'orderNotFound':
        return orderNotFound;
      case 'downloadInvoice':
        return downloadInvoice;
      case 'switchCodToOnline':
        return switchCodToOnline;
      case 'openingPaymentGateway':
        return openingPaymentGateway;
      case 'shop':
        return shop;
      case 'returnOrder':
        return returnOrder;
      case 'contactSupport':
        return contactSupport;
      case 'cancelConfirmMessage':
        return cancelConfirmMessage;
      case 'no':
        return no;
      case 'yesCancel':
        return yesCancel;
      case 'enterReturnReason':
        return enterReturnReason;
      case 'orderCancelled':
        return orderCancelled;
      case 'returnRequested':
        return returnRequested;
      case 'trustQualityProofs':
        return trustQualityProofs;
      case 'ourTeam':
        return ourTeam;
      case 'time':
        return time;
      case 'packedBy':
        return packedBy(arguments?['name'] as Object? ?? '');
      case 'viewPhotoProof':
        return viewPhotoProof;
      case 'realWeightGuarantee':
        return realWeightGuarantee;
      case 'perfectWeight':
        return perfectWeight;
      case 'overPackedMsg':
        return overPackedMsg(arguments?['diff'] as Object? ?? '');
      case 'underWeightMsg':
        return underWeightMsg(arguments?['refund'] as Object? ?? '');
      case 'ordered':
        return ordered;
      case 'weightProof':
        return weightProof;
      case 'viewPhoto':
        return viewPhoto;
      case 'labelHome':
        return labelHome;
      case 'labelWork':
        return labelWork;
      case 'labelVillageHome':
        return labelVillageHome;
      case 'labelFarm':
        return labelFarm;
      case 'labelOther':
        return labelOther;
      case 'typeHouse':
        return typeHouse;
      case 'typeApartment':
        return typeApartment;
      case 'typeShop':
        return typeShop;
      case 'propertyType':
        return propertyType;
      case 'addressType':
        return addressType;
      case 'landmarkLabel':
        return landmarkLabel;
      case 'villageColony':
        return villageColony;
      case 'pinCode':
        return pinCode;
      case 'voiceInstructions':
        return voiceInstructions;
      case 'setAsDefault':
        return setAsDefault;
      case 'savedAddresses':
        return savedAddresses;
      case 'addNew':
        return addNew;
      case 'noSavedAddresses':
        return noSavedAddresses;
      case 'noSavedAddressesSubtitle':
        return noSavedAddressesSubtitle;
      case 'addShippingAddress':
        return addShippingAddress;
      case 'editAddress':
        return editAddress;
      case 'addNewAddress':
        return addNewAddress;
      case 'saveAddress':
        return saveAddress;
      case 'updateAddress':
        return updateAddress;
      case 'invalidLabel':
        return invalidLabel;
      case 'invalidAddress':
        return invalidAddress;
      case 'invalidVillage':
        return invalidVillage;
      case 'invalidLandmark':
        return invalidLandmark;
      case 'invalidPinCode':
        return invalidPinCode;
      case 'fullAddress':
        return fullAddress;
      case 'recordingStop':
        return recordingStop;
      case 'voiceTagAttached':
        return voiceTagAttached;
      case 'recordDirectionHints':
        return recordDirectionHints;
      case 'deliveryInstructions':
        return deliveryInstructions;
      case 'fulfillment':
        return fulfillment;
      case 'packingDashboard':
        return packingDashboard;
      case 'todaysOrders':
        return todaysOrders;
      case 'statusNew':
        return statusNew;
      case 'packing':
        return packing;
      case 'ready':
        return ready;
      case 'qualityCheck':
        return qualityCheck;
      case 'quickStats':
        return quickStats;
      case 'efficiency':
        return efficiency;
      case 'qualityScore':
        return qualityScore;
      case 'itemsPacked':
        return itemsPacked;
      case 'quickActions':
        return quickActions;
      case 'acceptNewOrder':
        return acceptNewOrder;
      case 'viewPackingQueue':
        return viewPackingQueue;
      case 'printLabels':
        return printLabels;
      case 'orderQueue':
        return orderQueue;
      case 'searchOrderOrCustomer':
        return searchOrderOrCustomer;
      case 'sortBy':
        return sortBy;
      case 'oldestFirst':
        return oldestFirst;
      case 'byPriority':
        return byPriority;
      case 'highestValue':
        return highestValue;
      case 'customerName':
        return customerName;
      case 'noOrdersAvailable':
        return noOrdersAvailable;
      case 'packOrder':
        return packOrder;
      case 'customer':
        return customer;
      case 'phone':
        return phone;
      case 'address':
        return address;
      case 'itemsToPack':
        return itemsToPack;
      case 'startPacking':
        return startPacking;
      case 'completePacking':
        return completePacking;
      case 'addSpecialNotes':
        return addSpecialNotes;
      case 'fragileItemsExample':
        return fragileItemsExample;
      case 'packingStarted':
        return packingStarted;
      case 'allItemsPacked':
        return allItemsPacked;
      case 'packingCompleted':
        return packingCompleted;
      case 'quantityPacked':
        return quantityPacked;
      case 'enterQuantity':
        return enterQuantity;
      case 'required':
        return required;
      case 'verifyItems':
        return verifyItems;
      case 'rejectionReason':
        return rejectionReason;
      case 'damageExample':
        return damageExample;
      case 'approveOrder':
        return approveOrder;
      case 'rejectOrder':
        return rejectOrder;
      case 'confirmRejection':
        return confirmRejection;
      case 'areYouSureReject':
        return areYouSureReject;
      case 'orderRejected':
        return orderRejected;
      case 'orderApproved':
        return orderApproved;
      case 'noOrdersReadyQC':
        return noOrdersReadyQC;
      case 'itemsPerMin':
        return itemsPerMin;
      case 'verifyBarcode':
        return verifyBarcode;
      case 'scanBarcode':
        return scanBarcode;
      case 'printLabel':
        return printLabel;
      case 'labelPrintedSuccess':
        return labelPrintedSuccess;
      case 'printFailed':
        return printFailed;
      case 'orderAssigned':
        return orderAssigned(arguments?['id'] as Object? ?? '');
      case 'created':
        return created;
      case 'minutesAgo':
        return minutesAgo(arguments?['count'] as Object? ?? '');
      case 'highPriority':
        return highPriority;
      case 'viewAndAccept':
        return viewAndAccept;
      case 'continueWithOrders':
        return continueWithOrders;
      case 'reviewPackedOrders':
        return reviewPackedOrders;
      case 'noOrdersAssigned':
        return noOrdersAssigned;
      case 'taskNotFound':
        return taskNotFound;
      case 'loadingTask':
        return loadingTask;
      case 'errorLoadingTask':
        return errorLoadingTask;
      case 'errorAcceptingOrder':
        return errorAcceptingOrder;
      case 'errorLoadingOrders':
        return errorLoadingOrders;
      default:
        return key;
    }
  }

  /// No description provided for @appTitle.
  ///
  /// In en, this message translates to:
  /// **'Fufaji Online'**
  String get appTitle;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @cart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get cart;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @orders.
  ///
  /// In en, this message translates to:
  /// **'Orders'**
  String get orders;

  /// No description provided for @wallet.
  ///
  /// In en, this message translates to:
  /// **'Wallet'**
  String get wallet;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @searchProducts.
  ///
  /// In en, this message translates to:
  /// **'Search products...'**
  String get searchProducts;

  /// No description provided for @category.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get category;

  /// No description provided for @addToCart.
  ///
  /// In en, this message translates to:
  /// **'Add to Cart'**
  String get addToCart;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax (GST)'**
  String get tax;

  /// No description provided for @discount.
  ///
  /// In en, this message translates to:
  /// **'Discount'**
  String get discount;

  /// No description provided for @deliveryFee.
  ///
  /// In en, this message translates to:
  /// **'Delivery Fee'**
  String get deliveryFee;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @placeOrder.
  ///
  /// In en, this message translates to:
  /// **'Place Order'**
  String get placeOrder;

  /// No description provided for @orderStatus.
  ///
  /// In en, this message translates to:
  /// **'Order Status'**
  String get orderStatus;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @offlineMode.
  ///
  /// In en, this message translates to:
  /// **'Offline Mode'**
  String get offlineMode;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @rewards.
  ///
  /// In en, this message translates to:
  /// **'Rewards'**
  String get rewards;

  /// No description provided for @balance.
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get balance;

  /// No description provided for @cashback.
  ///
  /// In en, this message translates to:
  /// **'Cashback'**
  String get cashback;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @noInternet.
  ///
  /// In en, this message translates to:
  /// **'No internet connection. You are browsing offline.'**
  String get noInternet;

  /// No description provided for @delivery.
  ///
  /// In en, this message translates to:
  /// **'Delivery'**
  String get delivery;

  /// No description provided for @employee.
  ///
  /// In en, this message translates to:
  /// **'Employee'**
  String get employee;

  /// No description provided for @owner.
  ///
  /// In en, this message translates to:
  /// **'Owner'**
  String get owner;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @inventory.
  ///
  /// In en, this message translates to:
  /// **'Inventory'**
  String get inventory;

  /// No description provided for @products.
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get products;

  /// No description provided for @sales.
  ///
  /// In en, this message translates to:
  /// **'Sales'**
  String get sales;

  /// No description provided for @analytics.
  ///
  /// In en, this message translates to:
  /// **'Analytics'**
  String get analytics;

  /// No description provided for @packOrders.
  ///
  /// In en, this message translates to:
  /// **'Pack Orders'**
  String get packOrders;

  /// No description provided for @startDelivery.
  ///
  /// In en, this message translates to:
  /// **'Start Delivery'**
  String get startDelivery;

  /// No description provided for @markDelivered.
  ///
  /// In en, this message translates to:
  /// **'Mark Delivered'**
  String get markDelivered;

  /// No description provided for @lowStock.
  ///
  /// In en, this message translates to:
  /// **'Low Stock'**
  String get lowStock;

  /// No description provided for @outOfStock.
  ///
  /// In en, this message translates to:
  /// **'Out of Stock'**
  String get outOfStock;

  /// No description provided for @confirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get confirmed;

  /// No description provided for @processing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get processing;

  /// No description provided for @packed.
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get packed;

  /// No description provided for @outForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for Delivery'**
  String get outForDelivery;

  /// No description provided for @delivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get delivered;

  /// No description provided for @cancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get cancelled;

  /// No description provided for @returns.
  ///
  /// In en, this message translates to:
  /// **'Returns'**
  String get returns;

  /// No description provided for @attendance.
  ///
  /// In en, this message translates to:
  /// **'Attendance'**
  String get attendance;

  /// No description provided for @scan.
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get scan;

  /// No description provided for @voice.
  ///
  /// In en, this message translates to:
  /// **'Voice'**
  String get voice;

  /// No description provided for @help.
  ///
  /// In en, this message translates to:
  /// **'Help'**
  String get help;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @cash.
  ///
  /// In en, this message translates to:
  /// **'Cash'**
  String get cash;

  /// No description provided for @upi.
  ///
  /// In en, this message translates to:
  /// **'UPI'**
  String get upi;

  /// No description provided for @split.
  ///
  /// In en, this message translates to:
  /// **'Split Payment'**
  String get split;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @change.
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get change;

  /// No description provided for @insufficient.
  ///
  /// In en, this message translates to:
  /// **'Insufficient'**
  String get insufficient;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @managerPin.
  ///
  /// In en, this message translates to:
  /// **'Manager PIN'**
  String get managerPin;

  /// No description provided for @invalidPin.
  ///
  /// In en, this message translates to:
  /// **'Invalid PIN!'**
  String get invalidPin;

  /// No description provided for @linkCustomer.
  ///
  /// In en, this message translates to:
  /// **'Link Customer'**
  String get linkCustomer;

  /// No description provided for @riderCashLimit.
  ///
  /// In en, this message translates to:
  /// **'Rider Cash Limit'**
  String get riderCashLimit;

  /// No description provided for @settleCash.
  ///
  /// In en, this message translates to:
  /// **'Settle Cash'**
  String get settleCash;

  /// No description provided for @pendingSettlement.
  ///
  /// In en, this message translates to:
  /// **'Pending Settlement'**
  String get pendingSettlement;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @reason.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reason;

  /// No description provided for @inStock.
  ///
  /// In en, this message translates to:
  /// **'In Stock'**
  String get inStock;

  /// No description provided for @onlyLeft.
  ///
  /// In en, this message translates to:
  /// **'Only {count} left'**
  String onlyLeft(Object count);

  /// No description provided for @weight.
  ///
  /// In en, this message translates to:
  /// **'Weight'**
  String get weight;

  /// No description provided for @quantity.
  ///
  /// In en, this message translates to:
  /// **'Quantity'**
  String get quantity;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @mrp.
  ///
  /// In en, this message translates to:
  /// **'MRP'**
  String get mrp;

  /// No description provided for @aisle.
  ///
  /// In en, this message translates to:
  /// **'Aisle'**
  String get aisle;

  /// No description provided for @shelf.
  ///
  /// In en, this message translates to:
  /// **'Shelf'**
  String get shelf;

  /// No description provided for @batch.
  ///
  /// In en, this message translates to:
  /// **'Batch'**
  String get batch;

  /// No description provided for @expiry.
  ///
  /// In en, this message translates to:
  /// **'Expiry'**
  String get expiry;

  /// No description provided for @revenue.
  ///
  /// In en, this message translates to:
  /// **'Revenue'**
  String get revenue;

  /// No description provided for @profit.
  ///
  /// In en, this message translates to:
  /// **'Profit'**
  String get profit;

  /// No description provided for @growth.
  ///
  /// In en, this message translates to:
  /// **'Growth'**
  String get growth;

  /// No description provided for @topSelling.
  ///
  /// In en, this message translates to:
  /// **'Top Selling'**
  String get topSelling;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @stepPhone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get stepPhone;

  /// No description provided for @stepCart.
  ///
  /// In en, this message translates to:
  /// **'Cart'**
  String get stepCart;

  /// No description provided for @stepAddress.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get stepAddress;

  /// No description provided for @stepPayment.
  ///
  /// In en, this message translates to:
  /// **'Payment'**
  String get stepPayment;

  /// No description provided for @stepDone.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get stepDone;

  /// No description provided for @verifyPhone.
  ///
  /// In en, this message translates to:
  /// **'Verify Phone'**
  String get verifyPhone;

  /// No description provided for @confirmDeliveryInfo.
  ///
  /// In en, this message translates to:
  /// **'Confirm your delivery information'**
  String get confirmDeliveryInfo;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @enterPhoneHint.
  ///
  /// In en, this message translates to:
  /// **'Enter 10-digit phone number'**
  String get enterPhoneHint;

  /// No description provided for @sendOtp.
  ///
  /// In en, this message translates to:
  /// **'Send OTP'**
  String get sendOtp;

  /// No description provided for @enterOtp.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP'**
  String get enterOtp;

  /// No description provided for @enterOtpSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter OTP sent to +91-{phone}'**
  String enterOtpSentTo(Object phone);

  /// No description provided for @otpHint.
  ///
  /// In en, this message translates to:
  /// **'6-digit OTP'**
  String get otpHint;

  /// No description provided for @verifyOtp.
  ///
  /// In en, this message translates to:
  /// **'Verify OTP'**
  String get verifyOtp;

  /// No description provided for @verifyContinue.
  ///
  /// In en, this message translates to:
  /// **'Verify & Continue'**
  String get verifyContinue;

  /// No description provided for @resendOtp.
  ///
  /// In en, this message translates to:
  /// **'Didn\'t receive OTP? Resend'**
  String get resendOtp;

  /// No description provided for @invalidPhoneError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 10-digit phone number'**
  String get invalidPhoneError;

  /// No description provided for @tooManyAttempts.
  ///
  /// In en, this message translates to:
  /// **'Too many attempts. Try again in {minutes} minutes.'**
  String tooManyAttempts(Object minutes);

  /// No description provided for @invalidOtpError.
  ///
  /// In en, this message translates to:
  /// **'Enter a valid 6-digit OTP'**
  String get invalidOtpError;

  /// No description provided for @invalidOtp.
  ///
  /// In en, this message translates to:
  /// **'Invalid OTP'**
  String get invalidOtp;

  /// No description provided for @reviewOrder.
  ///
  /// In en, this message translates to:
  /// **'Review Your Order'**
  String get reviewOrder;

  /// No description provided for @items.
  ///
  /// In en, this message translates to:
  /// **'Items'**
  String get items;

  /// No description provided for @enterPromoCode.
  ///
  /// In en, this message translates to:
  /// **'Enter promo code'**
  String get enterPromoCode;

  /// No description provided for @promoApplied.
  ///
  /// In en, this message translates to:
  /// **'Promo code applied!'**
  String get promoApplied;

  /// No description provided for @promoInvalid.
  ///
  /// In en, this message translates to:
  /// **'Invalid promo code'**
  String get promoInvalid;

  /// No description provided for @deliveryFree.
  ///
  /// In en, this message translates to:
  /// **'FREE'**
  String get deliveryFree;

  /// No description provided for @continueToAddress.
  ///
  /// In en, this message translates to:
  /// **'Continue to Address'**
  String get continueToAddress;

  /// No description provided for @deliveryAddress.
  ///
  /// In en, this message translates to:
  /// **'Delivery Address'**
  String get deliveryAddress;

  /// No description provided for @deliveryInstructionsHint.
  ///
  /// In en, this message translates to:
  /// **'Delivery instructions (optional)'**
  String get deliveryInstructionsHint;

  /// No description provided for @deliveryType.
  ///
  /// In en, this message translates to:
  /// **'Delivery Type'**
  String get deliveryType;

  /// No description provided for @continueToPayment.
  ///
  /// In en, this message translates to:
  /// **'Continue to Payment'**
  String get continueToPayment;

  /// No description provided for @selectDeliveryDateTime.
  ///
  /// In en, this message translates to:
  /// **'Select Delivery Date & Time'**
  String get selectDeliveryDateTime;

  /// No description provided for @pleaseSelectAddress.
  ///
  /// In en, this message translates to:
  /// **'Please select a delivery address'**
  String get pleaseSelectAddress;

  /// No description provided for @choosePaymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Choose Payment Method'**
  String get choosePaymentMethod;

  /// No description provided for @cod.
  ///
  /// In en, this message translates to:
  /// **'Cash on Delivery (COD)'**
  String get cod;

  /// No description provided for @codSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pay when order arrives'**
  String get codSubtitle;

  /// No description provided for @upiSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Fast & secure payment'**
  String get upiSubtitle;

  /// No description provided for @myWallet.
  ///
  /// In en, this message translates to:
  /// **'My Wallet'**
  String get myWallet;

  /// No description provided for @walletAvailable.
  ///
  /// In en, this message translates to:
  /// **'₹{amount} available'**
  String walletAvailable(Object amount);

  /// No description provided for @walletBalanceRemaining.
  ///
  /// In en, this message translates to:
  /// **'Remaining ₹{amount} will be paid via COD'**
  String walletBalanceRemaining(Object amount);

  /// No description provided for @walletBalanceHeader.
  ///
  /// In en, this message translates to:
  /// **'Wallet Balance: ₹{balance} / ₹{total}'**
  String walletBalanceHeader(Object balance, Object total);

  /// No description provided for @processingPayment.
  ///
  /// In en, this message translates to:
  /// **'Processing payment...'**
  String get processingPayment;

  /// No description provided for @cancelOrder.
  ///
  /// In en, this message translates to:
  /// **'Cancel Order'**
  String get cancelOrder;

  /// No description provided for @orderConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Order Confirmed!'**
  String get orderConfirmed;

  /// No description provided for @orderNumberLabel.
  ///
  /// In en, this message translates to:
  /// **'Order #{number}'**
  String orderNumberLabel(Object number);

  /// No description provided for @estimatedDelivery.
  ///
  /// In en, this message translates to:
  /// **'Estimated Delivery'**
  String get estimatedDelivery;

  /// No description provided for @trackOrder.
  ///
  /// In en, this message translates to:
  /// **'Track Order'**
  String get trackOrder;

  /// No description provided for @continueShopping.
  ///
  /// In en, this message translates to:
  /// **'Continue Shopping'**
  String get continueShopping;

  /// No description provided for @paymentFailed.
  ///
  /// In en, this message translates to:
  /// **'Payment Failed'**
  String get paymentFailed;

  /// No description provided for @paymentFailedMessage.
  ///
  /// In en, this message translates to:
  /// **'Your payment could not be processed'**
  String get paymentFailedMessage;

  /// No description provided for @retryPayment.
  ///
  /// In en, this message translates to:
  /// **'Retry Payment'**
  String get retryPayment;

  /// No description provided for @severeWeatherAlert.
  ///
  /// In en, this message translates to:
  /// **'Severe Weather Alert'**
  String get severeWeatherAlert;

  /// No description provided for @weatherAdvisory.
  ///
  /// In en, this message translates to:
  /// **'Weather Advisory'**
  String get weatherAdvisory;

  /// No description provided for @fastest.
  ///
  /// In en, this message translates to:
  /// **'FASTEST'**
  String get fastest;

  /// No description provided for @quickBook.
  ///
  /// In en, this message translates to:
  /// **'QUICK BOOK'**
  String get quickBook;

  /// No description provided for @sourcingLocation.
  ///
  /// In en, this message translates to:
  /// **'Sourcing Location'**
  String get sourcingLocation;

  /// No description provided for @farmerPartner.
  ///
  /// In en, this message translates to:
  /// **'Local Farmer Partner'**
  String get farmerPartner;

  /// No description provided for @localSource.
  ///
  /// In en, this message translates to:
  /// **'Local Source'**
  String get localSource;

  /// No description provided for @certifiedOrganic.
  ///
  /// In en, this message translates to:
  /// **'Certified Organic'**
  String get certifiedOrganic;

  /// No description provided for @harvestedOn.
  ///
  /// In en, this message translates to:
  /// **'Harvested on: {date}'**
  String harvestedOn(Object date);

  /// No description provided for @freshnessVerified.
  ///
  /// In en, this message translates to:
  /// **'Freshness Verified'**
  String get freshnessVerified;

  /// No description provided for @sourcingTransparency.
  ///
  /// In en, this message translates to:
  /// **'This product is sourced directly from {source}. Scan QR code for full traceability.'**
  String sourcingTransparency(Object source);

  /// No description provided for @getDirections.
  ///
  /// In en, this message translates to:
  /// **'Get Directions'**
  String get getDirections;

  /// No description provided for @off.
  ///
  /// In en, this message translates to:
  /// **'OFF'**
  String get off;

  /// No description provided for @fixedPrice.
  ///
  /// In en, this message translates to:
  /// **'Fixed Price'**
  String get fixedPrice;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'ADD'**
  String get add;

  /// No description provided for @expiringSoon.
  ///
  /// In en, this message translates to:
  /// **'Expiring Soon'**
  String get expiringSoon;

  /// No description provided for @only.
  ///
  /// In en, this message translates to:
  /// **'Only'**
  String get only;

  /// No description provided for @left.
  ///
  /// In en, this message translates to:
  /// **'left'**
  String get left;

  /// No description provided for @myOrders.
  ///
  /// In en, this message translates to:
  /// **'My Orders'**
  String get myOrders;

  /// No description provided for @tabAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get tabAll;

  /// No description provided for @tabActive.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get tabActive;

  /// No description provided for @tabCompleted.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get tabCompleted;

  /// No description provided for @tabCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get tabCancelled;

  /// No description provided for @noOrdersYet.
  ///
  /// In en, this message translates to:
  /// **'No orders yet'**
  String get noOrdersYet;

  /// No description provided for @startShoppingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t placed any orders yet. Start shopping now!'**
  String get startShoppingSubtitle;

  /// No description provided for @startShopping.
  ///
  /// In en, this message translates to:
  /// **'Start Shopping'**
  String get startShopping;

  /// No description provided for @order.
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get order;

  /// No description provided for @moreItems.
  ///
  /// In en, this message translates to:
  /// **'more items'**
  String get moreItems;

  /// No description provided for @totalAmount.
  ///
  /// In en, this message translates to:
  /// **'Total Amount'**
  String get totalAmount;

  /// No description provided for @reorder.
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get reorder;

  /// No description provided for @claim.
  ///
  /// In en, this message translates to:
  /// **'Claim'**
  String get claim;

  /// No description provided for @track.
  ///
  /// In en, this message translates to:
  /// **'Track'**
  String get track;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today at {time}'**
  String todayAt(Object time);

  /// No description provided for @yesterday.
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get yesterday;

  /// No description provided for @daysAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} days ago'**
  String daysAgo(Object count);

  /// No description provided for @rewardWon.
  ///
  /// In en, this message translates to:
  /// **'YOU WON CASHBACK!'**
  String get rewardWon;

  /// No description provided for @creditedToWallet.
  ///
  /// In en, this message translates to:
  /// **'Credited to Wallet'**
  String get creditedToWallet;

  /// No description provided for @congratsCashback.
  ///
  /// In en, this message translates to:
  /// **'Congratulations! ₹{amount} cashback added to your wallet!'**
  String congratsCashback(Object amount);

  /// No description provided for @viewCart.
  ///
  /// In en, this message translates to:
  /// **'VIEW CART'**
  String get viewCart;

  /// No description provided for @unavailableItems.
  ///
  /// In en, this message translates to:
  /// **'Unavailable: {items}'**
  String unavailableItems(Object items);

  /// No description provided for @pricesUpdated.
  ///
  /// In en, this message translates to:
  /// **'Prices updated for: {count} items'**
  String pricesUpdated(Object count);

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusConfirmed.
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get statusConfirmed;

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statusProcessing;

  /// No description provided for @statusPacked.
  ///
  /// In en, this message translates to:
  /// **'Packed'**
  String get statusPacked;

  /// No description provided for @statusOutForDelivery.
  ///
  /// In en, this message translates to:
  /// **'Out for Delivery'**
  String get statusOutForDelivery;

  /// No description provided for @statusDelivered.
  ///
  /// In en, this message translates to:
  /// **'Delivered'**
  String get statusDelivered;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @statusReturned.
  ///
  /// In en, this message translates to:
  /// **'Returned'**
  String get statusReturned;

  /// No description provided for @statusRefunded.
  ///
  /// In en, this message translates to:
  /// **'Refunded'**
  String get statusRefunded;

  /// No description provided for @orderNotFound.
  ///
  /// In en, this message translates to:
  /// **'Order not found'**
  String get orderNotFound;

  /// No description provided for @downloadInvoice.
  ///
  /// In en, this message translates to:
  /// **'Download Invoice'**
  String get downloadInvoice;

  /// No description provided for @switchCodToOnline.
  ///
  /// In en, this message translates to:
  /// **'Switch from COD to Online Payment'**
  String get switchCodToOnline;

  /// No description provided for @openingPaymentGateway.
  ///
  /// In en, this message translates to:
  /// **'Opening secure payment gateway...'**
  String get openingPaymentGateway;

  /// No description provided for @shop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get shop;

  /// No description provided for @returnOrder.
  ///
  /// In en, this message translates to:
  /// **'Return Order'**
  String get returnOrder;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @cancelConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to cancel this order?'**
  String get cancelConfirmMessage;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @yesCancel.
  ///
  /// In en, this message translates to:
  /// **'Yes, Cancel'**
  String get yesCancel;

  /// No description provided for @enterReturnReason.
  ///
  /// In en, this message translates to:
  /// **'Enter reason for return'**
  String get enterReturnReason;

  /// No description provided for @orderCancelled.
  ///
  /// In en, this message translates to:
  /// **'Order Cancelled'**
  String get orderCancelled;

  /// No description provided for @returnRequested.
  ///
  /// In en, this message translates to:
  /// **'Return Requested'**
  String get returnRequested;

  /// No description provided for @trustQualityProofs.
  ///
  /// In en, this message translates to:
  /// **'Trust & Quality Proofs'**
  String get trustQualityProofs;

  /// No description provided for @ourTeam.
  ///
  /// In en, this message translates to:
  /// **'Our Team'**
  String get ourTeam;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @packedBy.
  ///
  /// In en, this message translates to:
  /// **'Packed with care by {name}'**
  String packedBy(Object name);

  /// No description provided for @viewPhotoProof.
  ///
  /// In en, this message translates to:
  /// **'View Photo Proof'**
  String get viewPhotoProof;

  /// No description provided for @realWeightGuarantee.
  ///
  /// In en, this message translates to:
  /// **'Real Weight Guarantee'**
  String get realWeightGuarantee;

  /// No description provided for @perfectWeight.
  ///
  /// In en, this message translates to:
  /// **'Perfect weight'**
  String get perfectWeight;

  /// No description provided for @overPackedMsg.
  ///
  /// In en, this message translates to:
  /// **'+{diff}kg free extra!'**
  String overPackedMsg(Object diff);

  /// No description provided for @underWeightMsg.
  ///
  /// In en, this message translates to:
  /// **'Underweight (₹{refund} refunded)'**
  String underWeightMsg(Object refund);

  /// No description provided for @ordered.
  ///
  /// In en, this message translates to:
  /// **'Ordered'**
  String get ordered;

  /// No description provided for @weightProof.
  ///
  /// In en, this message translates to:
  /// **'Weight Proof'**
  String get weightProof;

  /// No description provided for @viewPhoto.
  ///
  /// In en, this message translates to:
  /// **'View Photo'**
  String get viewPhoto;

  /// No description provided for @labelHome.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get labelHome;

  /// No description provided for @labelWork.
  ///
  /// In en, this message translates to:
  /// **'Work'**
  String get labelWork;

  /// No description provided for @labelVillageHome.
  ///
  /// In en, this message translates to:
  /// **'Village Home'**
  String get labelVillageHome;

  /// No description provided for @labelFarm.
  ///
  /// In en, this message translates to:
  /// **'Farm'**
  String get labelFarm;

  /// No description provided for @labelOther.
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get labelOther;

  /// No description provided for @typeHouse.
  ///
  /// In en, this message translates to:
  /// **'House'**
  String get typeHouse;

  /// No description provided for @typeApartment.
  ///
  /// In en, this message translates to:
  /// **'Apartment'**
  String get typeApartment;

  /// No description provided for @typeShop.
  ///
  /// In en, this message translates to:
  /// **'Shop'**
  String get typeShop;

  /// No description provided for @propertyType.
  ///
  /// In en, this message translates to:
  /// **'Property Type'**
  String get propertyType;

  /// No description provided for @addressType.
  ///
  /// In en, this message translates to:
  /// **'Address Type'**
  String get addressType;

  /// No description provided for @landmarkLabel.
  ///
  /// In en, this message translates to:
  /// **'Landmark'**
  String get landmarkLabel;

  /// No description provided for @villageColony.
  ///
  /// In en, this message translates to:
  /// **'Village or Colony'**
  String get villageColony;

  /// No description provided for @pinCode.
  ///
  /// In en, this message translates to:
  /// **'PIN Code'**
  String get pinCode;

  /// No description provided for @voiceInstructions.
  ///
  /// In en, this message translates to:
  /// **'Voice Instructions (for Rider)'**
  String get voiceInstructions;

  /// No description provided for @setAsDefault.
  ///
  /// In en, this message translates to:
  /// **'Set as default shipping address'**
  String get setAsDefault;

  /// No description provided for @savedAddresses.
  ///
  /// In en, this message translates to:
  /// **'Saved Addresses'**
  String get savedAddresses;

  /// No description provided for @addNew.
  ///
  /// In en, this message translates to:
  /// **'Add New'**
  String get addNew;

  /// No description provided for @noSavedAddresses.
  ///
  /// In en, this message translates to:
  /// **'No saved addresses'**
  String get noSavedAddresses;

  /// No description provided for @noSavedAddressesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t saved any addresses yet. Add one to speed up checkout.'**
  String get noSavedAddressesSubtitle;

  /// No description provided for @addShippingAddress.
  ///
  /// In en, this message translates to:
  /// **'Add Shipping Address'**
  String get addShippingAddress;

  /// No description provided for @editAddress.
  ///
  /// In en, this message translates to:
  /// **'Edit Address'**
  String get editAddress;

  /// No description provided for @addNewAddress.
  ///
  /// In en, this message translates to:
  /// **'Add New Address'**
  String get addNewAddress;

  /// No description provided for @saveAddress.
  ///
  /// In en, this message translates to:
  /// **'Save Address'**
  String get saveAddress;

  /// No description provided for @updateAddress.
  ///
  /// In en, this message translates to:
  /// **'Update Address'**
  String get updateAddress;

  /// No description provided for @invalidLabel.
  ///
  /// In en, this message translates to:
  /// **'Please specify label'**
  String get invalidLabel;

  /// No description provided for @invalidAddress.
  ///
  /// In en, this message translates to:
  /// **'Please enter address details'**
  String get invalidAddress;

  /// No description provided for @invalidVillage.
  ///
  /// In en, this message translates to:
  /// **'Please enter village/colony'**
  String get invalidVillage;

  /// No description provided for @invalidLandmark.
  ///
  /// In en, this message translates to:
  /// **'Landmark helps rider find you faster'**
  String get invalidLandmark;

  /// No description provided for @invalidPinCode.
  ///
  /// In en, this message translates to:
  /// **'Please enter valid 6-digit PIN code'**
  String get invalidPinCode;

  /// No description provided for @fullAddress.
  ///
  /// In en, this message translates to:
  /// **'House No. / Building / Street'**
  String get fullAddress;

  /// No description provided for @recordingStop.
  ///
  /// In en, this message translates to:
  /// **'Recording... Tap to Stop'**
  String get recordingStop;

  /// No description provided for @voiceTagAttached.
  ///
  /// In en, this message translates to:
  /// **'Voice Tag Attached ✅'**
  String get voiceTagAttached;

  /// No description provided for @recordDirectionHints.
  ///
  /// In en, this message translates to:
  /// **'Record direction hints (e.g. \'Behind the big Banyan tree\')'**
  String get recordDirectionHints;

  /// No description provided for @deliveryInstructions.
  ///
  /// In en, this message translates to:
  /// **'Delivery Instructions (Optional)'**
  String get deliveryInstructions;

  /// No description provided for @fulfillment.
  ///
  /// In en, this message translates to:
  /// **'Fulfillment'**
  String get fulfillment;

  /// No description provided for @packingDashboard.
  ///
  /// In en, this message translates to:
  /// **'Packing Dashboard'**
  String get packingDashboard;

  /// No description provided for @todaysOrders.
  ///
  /// In en, this message translates to:
  /// **'Today\'s Orders'**
  String get todaysOrders;

  /// No description provided for @statusNew.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get statusNew;

  /// No description provided for @packing.
  ///
  /// In en, this message translates to:
  /// **'Packing'**
  String get packing;

  /// No description provided for @ready.
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get ready;

  /// No description provided for @qualityCheck.
  ///
  /// In en, this message translates to:
  /// **'Quality Check'**
  String get qualityCheck;

  /// No description provided for @quickStats.
  ///
  /// In en, this message translates to:
  /// **'Quick Stats'**
  String get quickStats;

  /// No description provided for @efficiency.
  ///
  /// In en, this message translates to:
  /// **'Efficiency'**
  String get efficiency;

  /// No description provided for @qualityScore.
  ///
  /// In en, this message translates to:
  /// **'Quality Score'**
  String get qualityScore;

  /// No description provided for @itemsPacked.
  ///
  /// In en, this message translates to:
  /// **'Items Packed'**
  String get itemsPacked;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @acceptNewOrder.
  ///
  /// In en, this message translates to:
  /// **'Accept New Order'**
  String get acceptNewOrder;

  /// No description provided for @viewPackingQueue.
  ///
  /// In en, this message translates to:
  /// **'View Packing Queue'**
  String get viewPackingQueue;

  /// No description provided for @printLabels.
  ///
  /// In en, this message translates to:
  /// **'Print Labels'**
  String get printLabels;

  /// No description provided for @orderQueue.
  ///
  /// In en, this message translates to:
  /// **'Order Queue'**
  String get orderQueue;

  /// No description provided for @searchOrderOrCustomer.
  ///
  /// In en, this message translates to:
  /// **'Search order #, customer name'**
  String get searchOrderOrCustomer;

  /// No description provided for @sortBy.
  ///
  /// In en, this message translates to:
  /// **'Sort By'**
  String get sortBy;

  /// No description provided for @oldestFirst.
  ///
  /// In en, this message translates to:
  /// **'Oldest First'**
  String get oldestFirst;

  /// No description provided for @byPriority.
  ///
  /// In en, this message translates to:
  /// **'By Priority'**
  String get byPriority;

  /// No description provided for @highestValue.
  ///
  /// In en, this message translates to:
  /// **'Highest Value'**
  String get highestValue;

  /// No description provided for @customerName.
  ///
  /// In en, this message translates to:
  /// **'Customer Name'**
  String get customerName;

  /// No description provided for @noOrdersAvailable.
  ///
  /// In en, this message translates to:
  /// **'No orders available'**
  String get noOrdersAvailable;

  /// No description provided for @packOrder.
  ///
  /// In en, this message translates to:
  /// **'Pack Order'**
  String get packOrder;

  /// No description provided for @customer.
  ///
  /// In en, this message translates to:
  /// **'Customer'**
  String get customer;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @itemsToPack.
  ///
  /// In en, this message translates to:
  /// **'Items to Pack'**
  String get itemsToPack;

  /// No description provided for @startPacking.
  ///
  /// In en, this message translates to:
  /// **'Start Packing'**
  String get startPacking;

  /// No description provided for @completePacking.
  ///
  /// In en, this message translates to:
  /// **'Complete Packing'**
  String get completePacking;

  /// No description provided for @addSpecialNotes.
  ///
  /// In en, this message translates to:
  /// **'Add any special notes (optional)'**
  String get addSpecialNotes;

  /// No description provided for @fragileItemsExample.
  ///
  /// In en, this message translates to:
  /// **'E.g., Fragile items, Handle with care'**
  String get fragileItemsExample;

  /// No description provided for @packingStarted.
  ///
  /// In en, this message translates to:
  /// **'Packing started'**
  String get packingStarted;

  /// No description provided for @allItemsPacked.
  ///
  /// In en, this message translates to:
  /// **'Please pack all items before completing'**
  String get allItemsPacked;

  /// No description provided for @packingCompleted.
  ///
  /// In en, this message translates to:
  /// **'Packing completed successfully'**
  String get packingCompleted;

  /// No description provided for @quantityPacked.
  ///
  /// In en, this message translates to:
  /// **'Quantity Packed'**
  String get quantityPacked;

  /// No description provided for @enterQuantity.
  ///
  /// In en, this message translates to:
  /// **'Enter quantity'**
  String get enterQuantity;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @verifyItems.
  ///
  /// In en, this message translates to:
  /// **'Verify Items'**
  String get verifyItems;

  /// No description provided for @rejectionReason.
  ///
  /// In en, this message translates to:
  /// **'Rejection Reason (if rejecting)'**
  String get rejectionReason;

  /// No description provided for @damageExample.
  ///
  /// In en, this message translates to:
  /// **'E.g., Damaged items, Missing items, Incorrect quantity'**
  String get damageExample;

  /// No description provided for @approveOrder.
  ///
  /// In en, this message translates to:
  /// **'Approve Order'**
  String get approveOrder;

  /// No description provided for @rejectOrder.
  ///
  /// In en, this message translates to:
  /// **'Reject Order'**
  String get rejectOrder;

  /// No description provided for @confirmRejection.
  ///
  /// In en, this message translates to:
  /// **'Confirm Rejection'**
  String get confirmRejection;

  /// No description provided for @areYouSureReject.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to reject this order?'**
  String get areYouSureReject;

  /// No description provided for @orderRejected.
  ///
  /// In en, this message translates to:
  /// **'Order rejected. Sent back for repacking'**
  String get orderRejected;

  /// No description provided for @orderApproved.
  ///
  /// In en, this message translates to:
  /// **'Order approved successfully'**
  String get orderApproved;

  /// No description provided for @noOrdersReadyQC.
  ///
  /// In en, this message translates to:
  /// **'No orders ready for QC'**
  String get noOrdersReadyQC;

  /// No description provided for @itemsPerMin.
  ///
  /// In en, this message translates to:
  /// **'Items/min'**
  String get itemsPerMin;

  /// No description provided for @verifyBarcode.
  ///
  /// In en, this message translates to:
  /// **'Verify'**
  String get verifyBarcode;

  /// No description provided for @scanBarcode.
  ///
  /// In en, this message translates to:
  /// **'Scan barcode'**
  String get scanBarcode;

  /// No description provided for @printLabel.
  ///
  /// In en, this message translates to:
  /// **'Print Label'**
  String get printLabel;

  /// No description provided for @labelPrintedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Label printed successfully'**
  String get labelPrintedSuccess;

  /// No description provided for @printFailed.
  ///
  /// In en, this message translates to:
  /// **'Print failed'**
  String get printFailed;

  /// No description provided for @orderAssigned.
  ///
  /// In en, this message translates to:
  /// **'Order {id} accepted'**
  String orderAssigned(Object id);

  /// No description provided for @created.
  ///
  /// In en, this message translates to:
  /// **'Created'**
  String get created;

  /// No description provided for @minutesAgo.
  ///
  /// In en, this message translates to:
  /// **'{count} min ago'**
  String minutesAgo(Object count);

  /// No description provided for @highPriority.
  ///
  /// In en, this message translates to:
  /// **'HIGH PRIORITY'**
  String get highPriority;

  /// No description provided for @viewAndAccept.
  ///
  /// In en, this message translates to:
  /// **'View and accept pending orders'**
  String get viewAndAccept;

  /// No description provided for @continueWithOrders.
  ///
  /// In en, this message translates to:
  /// **'Continue with assigned orders'**
  String get continueWithOrders;

  /// No description provided for @reviewPackedOrders.
  ///
  /// In en, this message translates to:
  /// **'Review packed orders'**
  String get reviewPackedOrders;

  /// No description provided for @noOrdersAssigned.
  ///
  /// In en, this message translates to:
  /// **'No orders assigned'**
  String get noOrdersAssigned;

  /// No description provided for @taskNotFound.
  ///
  /// In en, this message translates to:
  /// **'Task not found'**
  String get taskNotFound;

  /// No description provided for @loadingTask.
  ///
  /// In en, this message translates to:
  /// **'Loading task...'**
  String get loadingTask;

  /// No description provided for @errorLoadingTask.
  ///
  /// In en, this message translates to:
  /// **'Error loading task'**
  String get errorLoadingTask;

  /// No description provided for @errorAcceptingOrder.
  ///
  /// In en, this message translates to:
  /// **'Error accepting order'**
  String get errorAcceptingOrder;

  /// No description provided for @errorLoadingOrders.
  ///
  /// In en, this message translates to:
  /// **'Error loading orders'**
  String get errorLoadingOrders;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['en', 'hi'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hi':
      return AppLocalizationsHi();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
