import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:file_selector/file_selector.dart';
import 'package:provider/provider.dart';

import '../../models/vendor_model.dart';
import '../../providers/app_state.dart';
import '../../features/operations/services/location_service.dart';
import '../../widgets/custom_text_field.dart';
import '../../widgets/toast_widget.dart';
import 'vendor_registration_success_screen.dart';

// ── Palette ─────────────────────────────────────────────────────────────────
// Matches the vendor login screen so the whole vendor flow feels like one
// coherent, premium product rather than two differently-styled screens.
const _kOrange = Color(0xFFE8541A);
const _kOrangeDeep = Color(0xFFC63A0E);
const _kOrangeLight = Color(0xFFFFF1EA);
const _kBg = Color(0xFFF6F6F8);
const _kCard = Colors.white;
const _kTextDark = Color(0xFF15131A);
const _kTextMid = Color(0xFF86869A);
const _kTextFaint = Color(0xFFB4B4C4);
const _kBorder = Color(0xFFE9E9EE);
const _kRed = Color(0xFFEF4444);
const _kGreen = Color(0xFF16A34A);

const _kHeroGradient = LinearGradient(
  colors: [Color(0xFFF9764A), Color(0xFFE8541A), Color(0xFFB93A0D)],
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
);

class VendorRegisterScreen extends StatefulWidget {
  const VendorRegisterScreen({super.key});

  static const routeName = '/vendor/register';

  @override
  State<VendorRegisterScreen> createState() => _VendorRegisterScreenState();
}

class _VendorRegisterScreenState extends State<VendorRegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ownerNameCtrl = TextEditingController();
  final _storeNameCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _businessTypeCtrl = TextEditingController();
  final _gstCtrl = TextEditingController();
  final _panCtrl = TextEditingController();
  final _storeAddressCtrl = TextEditingController();
  final _pickupAddressCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _stateCtrl = TextEditingController();
  final _pincodeCtrl = TextEditingController();
  final _bankHolderCtrl = TextEditingController();
  final _bankNumberCtrl = TextEditingController();
  final _ifscCtrl = TextEditingController();
  bool _termsAccepted = false;
  bool _loading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  String? _error;

  String? _storeLogo;
  String? _gstCertificate;
  String? _panCard;
  String? _cancelledCheque;
  String? _shopImageUrl;
  String? _storeLogoName;
  String? _gstCertificateName;
  String? _panCardName;
  String? _cancelledChequeName;
  String? _shopImageName;
  String? _uploadingField;
  List<VendorBusinessHour> _businessHours = _defaultVendorBusinessHours();
  bool _capturingPickupLocation = false;
  double? _pickupLatitude;
  double? _pickupLongitude;

  @override
  void initState() {
    super.initState();
    final vendor = context.read<AppState>().vendor;
    if (vendor != null) {
      _ownerNameCtrl.text = vendor.ownerName;
      _storeNameCtrl.text = vendor.name;
      _mobileCtrl.text = vendor.phone;
      _emailCtrl.text = vendor.email ?? '';
      _businessTypeCtrl.text = vendor.businessType;
      _gstCtrl.text = vendor.gstin;
      _panCtrl.text = vendor.panNumber;
      _storeAddressCtrl.text = vendor.address;
      _pickupAddressCtrl.text = vendor.pickupAddress;
      _pickupLatitude = vendor.pickupLatitude;
      _pickupLongitude = vendor.pickupLongitude;
      _cityCtrl.text = vendor.city;
      _stateCtrl.text = vendor.state;
      _pincodeCtrl.text = vendor.pincode;
      _bankHolderCtrl.text = vendor.bankAccountHolderName;
      _bankNumberCtrl.text = vendor.bankAccountNumber;
      _ifscCtrl.text = vendor.ifscCode;
      _storeLogo = vendor.logoUrl.isEmpty ? null : vendor.logoUrl;
      _gstCertificate = vendor.gstCertificateUrl.isEmpty
          ? null
          : vendor.gstCertificateUrl;
      _panCard = vendor.panCardUrl.isEmpty ? null : vendor.panCardUrl;
      _cancelledCheque = vendor.cancelledChequeUrl.isEmpty
          ? null
          : vendor.cancelledChequeUrl;
      _shopImageUrl = vendor.shopImageUrl.isEmpty ? null : vendor.shopImageUrl;
      _shopImageName = _shopImageUrl == null ? null : 'Uploaded banner';
      _businessHours = _normalizedVendorBusinessHours(vendor.businessHours);
    }
  }

  @override
  void dispose() {
    _ownerNameCtrl.dispose();
    _storeNameCtrl.dispose();
    _mobileCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    _businessTypeCtrl.dispose();
    _gstCtrl.dispose();
    _panCtrl.dispose();
    _storeAddressCtrl.dispose();
    _pickupAddressCtrl.dispose();
    _cityCtrl.dispose();
    _stateCtrl.dispose();
    _pincodeCtrl.dispose();
    _bankHolderCtrl.dispose();
    _bankNumberCtrl.dispose();
    _ifscCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickAsset({
    required String field,
    required List<XTypeGroup> acceptedTypeGroups,
    required void Function(String value) onSelected,
    required void Function(String value) onNameSelected,
  }) async {
    try {
      setState(() => _uploadingField = field);
      final api = context.read<AppState>().apiService;
      final file = await openFile(acceptedTypeGroups: acceptedTypeGroups);
      if (file == null) return;
      final fileName = file.name;
      final dynamic uploaded = kIsWeb
          ? await api.uploadImage(
              '/auth/vendor/upload-image',
              bytes: await file.readAsBytes(),
              fileName: fileName,
              fieldName: 'image',
            )
          : await api.uploadImage(
              '/auth/vendor/upload-image',
              filePath: file.path,
              fileName: fileName,
              fieldName: 'image',
            );
      final url = uploaded['url']?.toString();
      if (url == null || url.isEmpty) {
        throw StateError('Image upload failed');
      }
      onSelected(url);
      onNameSelected(fileName);
      if (mounted) setState(() {});
    } catch (e) {
      if (!mounted) return;
      setState(
        () => _error =
            'Upload failed: ${e.toString().replaceFirst('Exception: ', '')}',
      );
      showToast(context, _error!);
    } finally {
      if (mounted) setState(() => _uploadingField = null);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_termsAccepted) {
      HapticFeedback.vibrate();
      setState(() => _error = 'Please accept the Terms & Conditions');
      return;
    }
    if (_passwordCtrl.text != _confirmPasswordCtrl.text) {
      HapticFeedback.vibrate();
      setState(() => _error = 'Passwords do not match');
      return;
    }
    if (_pickupLatitude == null || _pickupLongitude == null) {
      HapticFeedback.vibrate();
      setState(
        () => _error =
            'Store pickup location is required. Tap "Use current location" before submitting.',
      );
      showToast(context, _error!);
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await context.read<AppState>().registerVendor(
        ownerName: _ownerNameCtrl.text.trim(),
        storeBusinessName: _storeNameCtrl.text.trim(),
        mobileNumber: _mobileCtrl.text.trim(),
        emailAddress: _emailCtrl.text.trim(),
        password: _passwordCtrl.text,
        confirmPassword: _confirmPasswordCtrl.text,
        businessType: _businessTypeCtrl.text.trim(),
        gstNumber: _gstCtrl.text.trim(),
        panNumber: _panCtrl.text.trim(),
        storeAddress: _storeAddressCtrl.text.trim(),
        pickupAddress: _pickupAddressCtrl.text.trim(),
        city: _cityCtrl.text.trim(),
        state: _stateCtrl.text.trim(),
        pincode: _pincodeCtrl.text.trim(),
        bankAccountHolderName: _bankHolderCtrl.text.trim(),
        bankAccountNumber: _bankNumberCtrl.text.trim().replaceAll(
          RegExp(r'[\s-]'),
          '',
        ),
        ifscCode: _ifscCtrl.text
            .trim()
            .replaceAll(RegExp(r'\s'), '')
            .toUpperCase(),
        storeLogo: _storeLogo ?? '',
        gstCertificate: _gstCertificate ?? '',
        panCard: _panCard ?? '',
        cancelledCheque: _cancelledCheque ?? '',
        shopImageUrl: _shopImageUrl ?? '',
        businessHours: _businessHours,
        pickupLatitude: _pickupLatitude,
        pickupLongitude: _pickupLongitude,
      );
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil(
        VendorRegistrationSuccessScreen.routeName,
        (route) => false,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
      showToast(context, _error!);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Scaffold(
      backgroundColor: _kBg,
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(18, 18, 18, 24 + bottomInset),
          children: [
            const _HeroCard(),
            const SizedBox(height: 18),
            Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionCard(
                    step: '1',
                    title: 'Owner Details',
                    subtitle: 'Who runs this store',
                    icon: Icons.person_rounded,
                    children: [
                      CustomTextField(
                        premium: true,
                        controller: _ownerNameCtrl,
                        label: 'Owner Name',
                        icon: Icons.person_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter owner name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _storeNameCtrl,
                        label: 'Store / Business Name',
                        icon: Icons.storefront_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter store name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _mobileCtrl,
                        label: 'Mobile Number',
                        icon: Icons.phone_iphone_rounded,
                        keyboardType: TextInputType.phone,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter mobile number'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _emailCtrl,
                        label: 'Email Address',
                        icon: Icons.email_rounded,
                        keyboardType: TextInputType.emailAddress,
                        validator: (v) {
                          final text = v?.trim() ?? '';
                          if (text.isEmpty) return 'Enter email';
                          if (!text.contains('@')) {
                            return 'Enter a valid email';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _passwordCtrl,
                        label: 'Password',
                        icon: Icons.lock_rounded,
                        obscureText: _obscurePassword,
                        suffix: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: _kTextFaint,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                        validator: (v) => (v == null || v.length < 6)
                            ? 'Use at least 6 characters'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _confirmPasswordCtrl,
                        label: 'Confirm Password',
                        icon: Icons.lock_outline_rounded,
                        obscureText: _obscureConfirm,
                        suffix: IconButton(
                          icon: Icon(
                            _obscureConfirm
                                ? Icons.visibility_off_rounded
                                : Icons.visibility_rounded,
                            color: _kTextFaint,
                            size: 20,
                          ),
                          onPressed: () => setState(
                            () => _obscureConfirm = !_obscureConfirm,
                          ),
                        ),
                        validator: (v) => (v == null || v.isEmpty)
                            ? 'Confirm password'
                            : (v != _passwordCtrl.text
                                  ? 'Passwords do not match'
                                  : null),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    step: '2',
                    title: 'Business Details',
                    subtitle: 'Registration & address information',
                    icon: Icons.business_center_rounded,
                    children: [
                      CustomTextField(
                        premium: true,
                        controller: _businessTypeCtrl,
                        label: 'Business Type',
                        icon: Icons.category_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter business type'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _gstCtrl,
                        label: 'GST Number',
                        icon: Icons.receipt_long_rounded,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _panCtrl,
                        label: 'PAN Number',
                        icon: Icons.badge_rounded,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _storeAddressCtrl,
                        label: 'Store Address',
                        icon: Icons.location_on_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter store address'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _pickupAddressCtrl,
                        label: 'Pickup Address',
                        icon: Icons.local_shipping_rounded,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter pickup address or use current location'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      _PickupLocationCard(
                        latitude: _pickupLatitude,
                        longitude: _pickupLongitude,
                        loading: _capturingPickupLocation,
                        onUseCurrentLocation: _capturePickupLocation,
                        onClear:
                            _pickupLatitude != null || _pickupLongitude != null
                            ? () => setState(() {
                                _pickupLatitude = null;
                                _pickupLongitude = null;
                              })
                            : null,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: CustomTextField(
                              premium: true,
                              controller: _cityCtrl,
                              label: 'City',
                              icon: Icons.location_city_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter city'
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: CustomTextField(
                              premium: true,
                              controller: _stateCtrl,
                              label: 'State',
                              icon: Icons.map_rounded,
                              validator: (v) => (v == null || v.trim().isEmpty)
                                  ? 'Enter state'
                                  : null,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _pincodeCtrl,
                        label: 'Pincode',
                        icon: Icons.local_post_office_rounded,
                        keyboardType: TextInputType.number,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Enter pincode'
                            : null,
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    step: '3',
                    title: 'Store Availability',
                    subtitle: 'Choose when customers can order from you',
                    icon: Icons.schedule_rounded,
                    children: [
                      _BusinessHoursEditor(
                        hours: _businessHours,
                        onChanged: (hours) =>
                            setState(() => _businessHours = hours),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    step: '4',
                    title: 'Bank Details',
                    subtitle: 'Where your payouts will be sent',
                    icon: Icons.account_balance_rounded,
                    children: [
                      CustomTextField(
                        premium: true,
                        controller: _bankHolderCtrl,
                        label: 'Bank Account Holder Name',
                        icon: Icons.person_pin_circle_rounded,
                        validator: (value) =>
                            value == null || value.trim().isEmpty
                            ? 'Enter the account holder name'
                            : null,
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _bankNumberCtrl,
                        label: 'Bank Account Number',
                        icon: Icons.account_balance_rounded,
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          final account = (value ?? '').replaceAll(
                            RegExp(r'[\s-]'),
                            '',
                          );
                          if (account.isEmpty) return 'Enter account number';
                          if (!RegExp(r'^\d{8,18}$').hasMatch(account)) {
                            return 'Use 8–18 digits';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      CustomTextField(
                        premium: true,
                        controller: _ifscCtrl,
                        label: 'IFSC Code',
                        icon: Icons.code_rounded,
                        validator: (value) {
                          final ifsc = (value ?? '')
                              .replaceAll(RegExp(r'\s'), '')
                              .toUpperCase();
                          if (ifsc.isEmpty) return 'Enter IFSC code';
                          if (!RegExp(
                            r'^[A-Z]{4}0[A-Z0-9]{6}$',
                          ).hasMatch(ifsc)) {
                            return 'Enter a valid IFSC code';
                          }
                          return null;
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    step: '5',
                    title: 'Document Uploads',
                    subtitle: 'Clear photos or scans work best',
                    icon: Icons.folder_copy_rounded,
                    children: [
                      _UploadTile(
                        title: 'Store Logo',
                        value: _storeLogoName,
                        uploading: _uploadingField == 'logo',
                        onTap: () => _pickAsset(
                          field: 'logo',
                          acceptedTypeGroups: const [
                            XTypeGroup(
                              label: 'Images',
                              extensions: ['jpg', 'jpeg', 'png', 'webp'],
                            ),
                          ],
                          onSelected: (value) => _storeLogo = value,
                          onNameSelected: (value) => _storeLogoName = value,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _UploadTile(
                        title: 'Shop Banner Photo',
                        value: _shopImageName,
                        uploading: _uploadingField == 'shop_banner',
                        onTap: () => _pickAsset(
                          field: 'shop_banner',
                          acceptedTypeGroups: const [
                            XTypeGroup(
                              label: 'Images',
                              extensions: ['jpg', 'jpeg', 'png', 'webp'],
                            ),
                          ],
                          onSelected: (value) => _shopImageUrl = value,
                          onNameSelected: (value) => _shopImageName = value,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _UploadTile(
                        title: 'GST Certificate',
                        value: _gstCertificateName,
                        uploading: _uploadingField == 'gst',
                        onTap: () => _pickAsset(
                          field: 'gst',
                          acceptedTypeGroups: const [
                            XTypeGroup(
                              label: 'Documents',
                              extensions: ['jpg', 'jpeg', 'png', 'pdf'],
                            ),
                          ],
                          onSelected: (value) => _gstCertificate = value,
                          onNameSelected: (value) =>
                              _gstCertificateName = value,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _UploadTile(
                        title: 'PAN Card',
                        value: _panCardName,
                        uploading: _uploadingField == 'pan',
                        onTap: () => _pickAsset(
                          field: 'pan',
                          acceptedTypeGroups: const [
                            XTypeGroup(
                              label: 'Documents',
                              extensions: ['jpg', 'jpeg', 'png', 'pdf'],
                            ),
                          ],
                          onSelected: (value) => _panCard = value,
                          onNameSelected: (value) => _panCardName = value,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _UploadTile(
                        title: 'Cancelled Cheque / Bank Proof',
                        value: _cancelledChequeName,
                        uploading: _uploadingField == 'cheque',
                        onTap: () => _pickAsset(
                          field: 'cheque',
                          acceptedTypeGroups: const [
                            XTypeGroup(
                              label: 'Documents',
                              extensions: ['jpg', 'jpeg', 'png', 'pdf'],
                            ),
                          ],
                          onSelected: (value) => _cancelledCheque = value,
                          onNameSelected: (value) =>
                              _cancelledChequeName = value,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  _TermsRow(
                    accepted: _termsAccepted,
                    onChanged: (value) =>
                        setState(() => _termsAccepted = value),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _error!),
                  ],
                  const SizedBox(height: 20),
                  _SubmitButton(loading: _loading, onTap: _submit),
                  const SizedBox(height: 16),
                  const _FooterNote(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _capturePickupLocation() async {
    setState(() => _capturingPickupLocation = true);
    try {
      final location = await LocationService().currentLocation();
      if (!mounted) return;
      final details = await LocationService().reverseGeocode(
        latitude: location.latitude,
        longitude: location.longitude,
      );
      if (!mounted) return;
      setState(() {
        _pickupLatitude = location.latitude;
        _pickupLongitude = location.longitude;
        if (details != null) {
          _pickupAddressCtrl.text = details.address;
          if (details.city.isNotEmpty) _cityCtrl.text = details.city;
          if (details.state.isNotEmpty) _stateCtrl.text = details.state;
          if (details.pincode.isNotEmpty) _pincodeCtrl.text = details.pincode;
        }
      });
      showToast(
        context,
        details == null
            ? 'Location captured. Enter the pickup address manually.'
            : 'Pickup address and location filled. Add a door number if needed.',
      );
    } catch (e) {
      if (!mounted) return;
      showToast(context, e.toString());
    } finally {
      if (mounted) setState(() => _capturingPickupLocation = false);
    }
  }
}

List<VendorBusinessHour> _defaultVendorBusinessHours() => List.generate(
  7,
  (day) => VendorBusinessHour(
    day: day,
    isOpen: true,
    openTime: '08:00',
    closeTime: '22:00',
  ),
);

List<VendorBusinessHour> _normalizedVendorBusinessHours(
  List<VendorBusinessHour> hours,
) {
  if (hours.length == 7) return hours;
  final byDay = {for (final hour in hours) hour.day: hour};
  return List.generate(
    7,
    (day) =>
        byDay[day] ??
        VendorBusinessHour(
          day: day,
          isOpen: true,
          openTime: '08:00',
          closeTime: '22:00',
        ),
  );
}

class _BusinessHoursEditor extends StatelessWidget {
  const _BusinessHoursEditor({required this.hours, required this.onChanged});

  final List<VendorBusinessHour> hours;
  final ValueChanged<List<VendorBusinessHour>> onChanged;

  static const _days = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

  Future<void> _pickTime(BuildContext context, int index, bool opening) async {
    final current = opening ? hours[index].openTime : hours[index].closeTime;
    final parts = current.split(':');
    final initial = TimeOfDay(
      hour: int.tryParse(parts.first) ?? (opening ? 8 : 22),
      minute: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
    );
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    final value =
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    onChanged(
      hours
          .map(
            (hour) => opening
                ? hour.copyWith(openTime: value)
                : hour.copyWith(closeTime: value),
          )
          .toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: List.generate(hours.length, (index) {
            final hour = hours[index];
            return FilterChip(
              selected: hour.isOpen,
              label: Text(_days[index]),
              onSelected: (value) {
                final updated = [...hours];
                updated[index] = hour.copyWith(isOpen: value);
                onChanged(updated);
              },
              selectedColor: _kOrangeLight,
              checkmarkColor: _kOrange,
              side: const BorderSide(color: _kBorder),
            );
          }),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _TimeButton(
                label: 'Open',
                value: hours.first.openTime,
                onTap: () => _pickTime(context, 0, true),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _TimeButton(
                label: 'Close',
                value: hours.first.closeTime,
                onTap: () => _pickTime(context, 0, false),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _TimeButton extends StatelessWidget {
  const _TimeButton({
    required this.label,
    required this.value,
    required this.onTap,
  });
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: const Icon(Icons.schedule_rounded),
      label: Text('$label $value'),
      style: OutlinedButton.styleFrom(
        foregroundColor: _kOrange,
        side: const BorderSide(color: _kOrange),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        padding: const EdgeInsets.symmetric(vertical: 14),
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: _kHeroGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: _kOrange.withValues(alpha: 0.30),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -30,
            right: -30,
            child: _Glow(size: 130, opacity: 0.10),
          ),
          Positioned(
            bottom: -30,
            left: -20,
            child: _Glow(size: 90, opacity: 0.08),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.22),
                        width: 1,
                      ),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.bolt_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 5),
                        Text(
                          'New Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: 0.24),
                        width: 1.2,
                      ),
                    ),
                    child: const Icon(
                      Icons.store_mall_directory_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vendor Registration',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.4,
                            height: 1.1,
                          ),
                        ),
                        SizedBox(height: 5),
                        Text(
                          'Submit your store details for Super Admin verification.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: opacity),
            Colors.white.withValues(alpha: 0),
          ],
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.step,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.children,
  });

  final String step;
  final String title;
  final String subtitle;
  final IconData icon;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: _kCard,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: _kBorder),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFFF9764A), Color(0xFFD44010)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(13),
                  boxShadow: [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.28),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(icon, color: Colors.white, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          title,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w900,
                            color: _kTextDark,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 12,
                        color: _kTextMid,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _kOrangeLight,
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _kOrange.withValues(alpha: 0.18)),
                ),
                child: Text(
                  step,
                  style: const TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w800,
                    color: _kOrangeDeep,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...children,
        ],
      ),
    );
  }
}

class _PickupLocationCard extends StatelessWidget {
  const _PickupLocationCard({
    required this.latitude,
    required this.longitude,
    required this.loading,
    required this.onUseCurrentLocation,
    required this.onClear,
  });

  final double? latitude;
  final double? longitude;
  final bool loading;
  final VoidCallback onUseCurrentLocation;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final hasLocation = latitude != null && longitude != null;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF9FAFC),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _kBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'PICKUP PIN',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.7,
              color: _kTextMid,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasLocation
                ? 'Saved pin: ${latitude!.toStringAsFixed(6)}, ${longitude!.toStringAsFixed(6)}'
                : 'Required: use the exact store pin so delivery partners reach the right pickup point.',
            style: const TextStyle(
              fontSize: 12.5,
              color: _kTextDark,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: FilledButton(
                  onPressed: loading ? null : onUseCurrentLocation,
                  style: FilledButton.styleFrom(
                    backgroundColor: _kOrange,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Use current location'),
                ),
              ),
              if (onClear != null) ...[
                const SizedBox(width: 10),
                OutlinedButton(
                  onPressed: onClear,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: _kTextDark,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Clear'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _UploadTile extends StatelessWidget {
  const _UploadTile({
    required this.title,
    required this.value,
    required this.uploading,
    required this.onTap,
  });

  final String title;
  final String? value;
  final bool uploading;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final uploaded = !uploading && value != null && value!.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            color: uploaded ? _kGreen.withValues(alpha: 0.045) : _kBg,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: uploaded ? _kGreen.withValues(alpha: 0.25) : _kBorder,
              width: 1.3,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: uploaded
                      ? _kGreen.withValues(alpha: 0.12)
                      : _kOrange.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  uploaded
                      ? Icons.check_circle_rounded
                      : Icons.upload_file_rounded,
                  color: uploaded ? _kGreen : _kOrangeDeep,
                  size: 19,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 13.5,
                        color: _kTextDark,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      uploading
                          ? 'Uploading...'
                          : (value == null || value!.isEmpty
                                ? 'Tap to upload'
                                : value!),
                      style: TextStyle(
                        color: uploaded ? _kGreen : _kTextMid,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (uploading)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    valueColor: AlwaysStoppedAnimation(_kOrange),
                  ),
                )
              else
                Icon(Icons.chevron_right_rounded, color: _kTextFaint, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _TermsRow extends StatelessWidget {
  const _TermsRow({required this.accepted, required this.onChanged});

  final bool accepted;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () => onChanged(!accepted),
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: accepted ? _kOrangeLight : _kCard,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: accepted ? _kOrange.withValues(alpha: 0.30) : _kBorder,
              width: 1.3,
            ),
          ),
          child: Row(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: accepted ? _kOrange : Colors.transparent,
                  borderRadius: BorderRadius.circular(7),
                  border: Border.all(
                    color: accepted
                        ? _kOrange
                        : _kTextFaint.withValues(alpha: 0.6),
                    width: 1.6,
                  ),
                ),
                child: accepted
                    ? const Icon(
                        Icons.check_rounded,
                        size: 15,
                        color: Colors.white,
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'I agree to the Terms & Conditions',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _kTextDark,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: _kRed.withValues(alpha: 0.22)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 22,
            height: 22,
            margin: const EdgeInsets.only(top: 1),
            decoration: BoxDecoration(
              color: _kRed.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(7),
            ),
            child: const Icon(
              Icons.priority_high_rounded,
              color: _kRed,
              size: 14,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: _kRed,
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SubmitButton extends StatefulWidget {
  const _SubmitButton({required this.loading, required this.onTap});

  final bool loading;
  final VoidCallback onTap;

  @override
  State<_SubmitButton> createState() => _SubmitButtonState();
}

class _SubmitButtonState extends State<_SubmitButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 110),
  );

  late final Animation<double> _s = Tween<double>(
    begin: 1.0,
    end: 0.965,
  ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut));

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.loading ? null : (_) => _c.forward(),
      onTapUp: widget.loading
          ? null
          : (_) {
              _c.reverse();
              widget.onTap();
            },
      onTapCancel: () => _c.reverse(),
      child: ScaleTransition(
        scale: _s,
        child: Container(
          width: double.infinity,
          height: 57,
          decoration: BoxDecoration(
            gradient: widget.loading
                ? null
                : const LinearGradient(
                    colors: [
                      Color(0xFFF9764A),
                      Color(0xFFE8541A),
                      Color(0xFFC63A0E),
                    ],
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                  ),
            color: widget.loading ? const Color(0xFFE2E2E6) : null,
            borderRadius: BorderRadius.circular(17),
            boxShadow: widget.loading
                ? []
                : [
                    BoxShadow(
                      color: _kOrange.withValues(alpha: 0.38),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                    BoxShadow(
                      color: _kOrangeDeep.withValues(alpha: 0.20),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ],
          ),
          child: Center(
            child: widget.loading
                ? const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          valueColor: AlwaysStoppedAnimation(_kTextMid),
                        ),
                      ),
                      SizedBox(width: 10),
                      Text(
                        'Submitting...',
                        style: TextStyle(
                          color: _kTextMid,
                          fontSize: 15,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  )
                : const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.verified_rounded,
                        color: Colors.white,
                        size: 19,
                      ),
                      SizedBox(width: 9),
                      Text(
                        'Submit for Approval',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  const _FooterNote();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.shield_outlined, size: 13, color: _kTextFaint),
          const SizedBox(width: 6),
          Text(
            'Your details are reviewed securely by our team',
            style: TextStyle(
              color: _kTextFaint,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
