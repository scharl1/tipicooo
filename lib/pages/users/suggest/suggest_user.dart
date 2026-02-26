import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/custom_buttons.dart';
import 'package:url_launcher/url_launcher.dart';

class SuggestUserPage extends StatefulWidget {
  const SuggestUserPage({super.key, required this.userId});

  final String userId;

  @override
  State<SuggestUserPage> createState() => _SuggestUserPageState();
}

class _SuggestUserPageState extends State<SuggestUserPage> {
  bool _savingQr = false;

  String get _referralLink =>
      "https://ilpassaparoladicarlo.com/benvenuti-in-tipic-ooo/?ref=${widget.userId}";

  Future<void> _saveQrToGallery() async {
    if (_savingQr) return;
    setState(() => _savingQr = true);
    try {
      final painter = QrPainter(
        data: _referralLink,
        version: QrVersions.auto,
        eyeStyle: const QrEyeStyle(
          eyeShape: QrEyeShape.square,
          color: Colors.black,
        ),
        dataModuleStyle: const QrDataModuleStyle(
          dataModuleShape: QrDataModuleShape.square,
          color: Colors.black,
        ),
      );

      final ByteData? data = await painter.toImageData(
        1800,
        format: ui.ImageByteFormat.png,
      );
      if (data == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Errore generazione QR.")),
        );
        return;
      }

      final Uint8List pngBytes = data.buffer.asUint8List();
      final fileName =
          "tipicooo_qr_invito_${DateTime.now().millisecondsSinceEpoch}.png";
      final xFile = XFile.fromData(
        pngBytes,
        mimeType: "image/png",
        name: fileName,
      );
      await Share.shareXFiles(
        [xFile],
        text: "QR invito Tipic.ooo",
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Errore esportazione QR."),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _savingQr = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BasePage(
      headerTitle: "Invita",
      showBack: true,
      scrollable: true,
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            const SizedBox(height: 8),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.black12),
              ),
              child: Column(
                children: [
                  const Text(
                    "QR invito",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  QrImageView(
                    data: _referralLink,
                    version: QrVersions.auto,
                    size: 170,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    "Fai scannerizzare questo codice per aprire il tuo link invito.",
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  BlueNarrowButton(
                    label: _savingQr ? "Preparazione..." : "Salva QR",
                    icon: Icons.download_outlined,
                    onPressed: _savingQr ? () {} : _saveQrToGallery,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            BlueNarrowButton(
              label: "Invita",
              icon: Icons.share,
              onPressed: () async {
                final message =
                    "Ciao, sto usando Tipic.ooo, un servizio che permette di condividere suggerimenti su attività e servizi. Se ti registri tramite il mio link si crea il collegamento necessario affinché, quando lo utilizzerai, potremo entrambi ricevere un piccolo rimborso sulle operazioni che farai. È gratuito e può risultare utile nella quotidianità.\n\n$_referralLink";

                final Uri appUri = Uri.parse(
                  "whatsapp://send?text=${Uri.encodeComponent(message)}",
                );
                final Uri fallbackUri = Uri.parse(
                  "https://api.whatsapp.com/send?text=${Uri.encodeComponent(message)}",
                );

                try {
                  final opened = await launchUrl(
                    appUri,
                    mode: LaunchMode.externalApplication,
                  );
                  if (!opened) {
                    await launchUrl(
                      fallbackUri,
                      mode: LaunchMode.externalApplication,
                    );
                  }
                } catch (_) {
                  await launchUrl(
                    fallbackUri,
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            BlueNarrowButton(
              label: "Invita via Email",
              icon: Icons.mail_outline,
              onPressed: () async {
                final subject = "Invito a Tipic.ooo";
                final body =
                    "Ciao,\n\n"
                    "sto usando Tipic.ooo, un servizio che permette di condividere suggerimenti su attività e servizi. "
                    "Se ti registri tramite il mio link si crea il collegamento necessario affinché, quando lo utilizzerai, "
                    "potremo entrambi ricevere un piccolo rimborso sulle operazioni che farai.\n\n"
                    "Apri questo link:\n"
                    "$_referralLink\n\n"
                    "È gratuito e può risultare utile nella quotidianità.";

                final subjectEncoded = Uri.encodeComponent(subject);
                final bodyEncoded = Uri.encodeComponent(body);
                final uri = Uri.parse(
                  "mailto:?subject=$subjectEncoded&body=$bodyEncoded",
                );

                final ok = await launchUrl(
                  uri,
                  mode: LaunchMode.externalApplication,
                );
                if (!ok && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text("Nessuna app email disponibile."),
                    ),
                  );
                }
              },
            ),
            const SizedBox(height: 20),
            BlueNarrowButton(
              label: "Copia link",
              icon: Icons.copy,
              onPressed: () {
                Clipboard.setData(ClipboardData(text: _referralLink));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Link copiato")),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
