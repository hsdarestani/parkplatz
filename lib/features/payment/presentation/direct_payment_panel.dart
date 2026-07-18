import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../config/design_tokens.dart';
import '../data/payment_repository.dart';

class DirectPaymentPanel extends StatefulWidget {
  const DirectPaymentPanel({
    super.key,
    required this.value,
    required this.busy,
    required this.onSubmit,
    required this.onUploadReceipt,
  });

  final DirectPaymentInstructions value;
  final bool busy;
  final Future<void> Function(String reference) onSubmit;
  final Future<ReceiptUpload> Function(Uint8List bytes, String filename)
      onUploadReceipt;

  @override
  State<DirectPaymentPanel> createState() => _DirectPaymentPanelState();
}

class _DirectPaymentPanelState extends State<DirectPaymentPanel> {
  final controller = TextEditingController();
  bool uploading = false;
  ReceiptUpload? receipt;

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final method = switch (value.method) {
      'paypal' => 'PayPal',
      'revolut' => 'Revolut',
      'sepa' => 'SEPA-Überweisung',
      _ => 'Direktzahlung',
    };
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: T.mintSoft,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: T.mint),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(Icons.account_balance_wallet_outlined, color: T.success),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Direkt an den Anbieter zahlen · $method',
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _CopyLine(label: 'Betrag', value: _money(value.amountCents)),
          _CopyLine(
            label: 'Verwendungszweck',
            value: value.paymentReference,
            copyable: true,
          ),
          if (value.iban != null && value.iban!.isNotEmpty)
            _CopyLine(label: 'IBAN', value: value.iban!, copyable: true),
          if (value.accountHolder != null && value.accountHolder!.isNotEmpty)
            _CopyLine(label: 'Empfänger', value: value.accountHolder!),
          if (value.instructions != null && value.instructions!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(value.instructions!, style: const TextStyle(color: T.muted)),
          ],
          if (value.paymentUrl != null && value.paymentUrl!.isNotEmpty) ...[
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: widget.busy ? null : _openPayment,
              icon: const Icon(Icons.open_in_new),
              label: Text('$method öffnen'),
            ),
          ],
          const SizedBox(height: 14),
          TextField(
            controller: controller,
            enabled: !widget.busy,
            decoration: const InputDecoration(
              labelText: 'Transaktions-ID oder Zahlungsreferenz',
              prefixIcon: Icon(Icons.receipt_long_outlined),
              helperText: 'Nach der Zahlung hier die Referenz eintragen.',
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: receipt == null ? T.line : T.mint),
            ),
            child: Row(
              children: [
                Icon(
                  receipt == null
                      ? Icons.upload_file_outlined
                      : Icons.check_circle_outline,
                  color: receipt == null ? T.muted : T.success,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    receipt == null
                        ? 'Optional: Zahlungsbeleg als JPG, PNG, WEBP oder PDF hochladen.'
                        : '${receipt!.originalName} wurde hochgeladen.',
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.busy || uploading ? null : _pickReceipt,
                  icon: uploading
                      ? const SizedBox(
                          width: 17,
                          height: 17,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.attach_file),
                  label: Text(receipt == null ? 'Beleg wählen' : 'Ersetzen'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: widget.busy || uploading
                ? null
                : () {
                    final reference = controller.text.trim();
                    if (reference.length < 3) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Bitte Zahlungsreferenz eintragen.'),
                        ),
                      );
                      return;
                    }
                    widget.onSubmit(reference);
                  },
            icon: widget.busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_outlined),
            label: Text(
              widget.busy
                  ? 'Wird gesendet …'
                  : 'Zahlung zur Bestätigung einreichen',
            ),
          ),
          const SizedBox(height: 9),
          const Text(
            'Die Buchung und genaue Adresse werden erst freigeschaltet, nachdem der Anbieter den Zahlungseingang bestätigt hat.',
            style: TextStyle(color: T.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Future<void> _pickReceipt() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp', 'pdf'],
      withData: true,
      allowMultiple: false,
    );
    final file = result?.files.single;
    final bytes = file?.bytes;
    if (file == null || bytes == null || !mounted) return;
    if (file.size > 5 * 1024 * 1024) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Der Beleg darf höchstens 5 MB groß sein.')),
      );
      return;
    }
    setState(() => uploading = true);
    try {
      final uploaded = await widget.onUploadReceipt(bytes, file.name);
      if (mounted) setState(() => receipt = uploaded);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
    } finally {
      if (mounted) setState(() => uploading = false);
    }
  }

  Future<void> _openPayment() async {
    final uri = Uri.tryParse(widget.value.paymentUrl ?? '');
    if (uri == null) return;
    final opened = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
      webOnlyWindowName: '_blank',
    );
    if (!opened && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Zahlungslink konnte nicht geöffnet werden.')),
      );
    }
  }
}

class _CopyLine extends StatelessWidget {
  const _CopyLine({
    required this.label,
    required this.value,
    this.copyable = false,
  });

  final String label;
  final String value;
  final bool copyable;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          children: [
            SizedBox(
              width: 125,
              child: Text(label, style: const TextStyle(color: T.muted)),
            ),
            Expanded(
              child: SelectableText(
                value,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            if (copyable)
              IconButton(
                tooltip: 'Kopieren',
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: value));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$label kopiert.')),
                    );
                  }
                },
                icon: const Icon(Icons.copy_outlined, size: 18),
              ),
          ],
        ),
      );
}

String _money(int cents) =>
    '${(cents / 100).toStringAsFixed(2).replaceAll('.', ',')} €';
