import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:tipicooo/widgets/base_page.dart';
import 'package:tipicooo/widgets/layout/app_body_layout.dart';
import 'package:tipicooo/theme/app_text_styles.dart';
import 'package:tipicooo/theme/app_colors.dart';

import 'package:tipicooo/hive/hive_register_activity.dart';
import 'package:tipicooo/hive/hive_photos_controller.dart';

import 'widgets/photo_preview.dart';
import 'widgets/add_photo_box.dart';

// IMPORT CORRETTO (UNICO)
import 'upload_picker.dart';

class RegisterActivityPage extends StatefulWidget {
  const RegisterActivityPage({super.key});

  @override
  State<RegisterActivityPage> createState() => _RegisterActivityPageState();
}

enum UserRoleType { owner, association, delegate }

class _RegisterActivityPageState extends State<RegisterActivityPage> {
  UserRoleType? _roleType;

  Widget buildInputBox({
    required String label,
    required String hiveKey,
    TextInputType keyboardType = TextInputType.text,
  }) {
    final initialValue = HiveRegisterActivity.loadField(hiveKey) ?? "";

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: TextField(
        controller: TextEditingController(text: initialValue),
        keyboardType: keyboardType,
        onChanged: (value) => HiveRegisterActivity.saveField(hiveKey, value),
        decoration: InputDecoration(labelText: label, border: InputBorder.none),
      ),
    );
  }

  Widget _roleButton({required String label, required UserRoleType value}) {
    final isSelected = _roleType == value;

    return InkWell(
      onTap: () => setState(() => _roleType = value),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primaryBlue.withValues(alpha: 0.1)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? AppColors.primaryBlue : Colors.grey.shade300,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: AppTextStyles.body.copyWith(
              color: isSelected ? AppColors.primaryBlue : AppColors.black,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }

  Widget _uploadBox({required String label}) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Icon(Icons.picture_as_pdf, color: AppColors.primaryBlue),
            const SizedBox(width: 12),
            Expanded(child: Text(label, style: AppTextStyles.body)),
          ],
        ),
      ),
    );
  }

  Widget _roleDocuments() {
    if (_roleType == null) return const SizedBox.shrink();

    switch (_roleType!) {
      case UserRoleType.owner:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: 16),
            Text("Documento richiesto", style: AppTextStyles.sectionTitle),
            SizedBox(height: 8),
            Text(
              "Per attività commerciali serve la visura camerale.",
              style: AppTextStyles.body,
            ),
          ],
        );
      case UserRoleType.association:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: 16),
            Text("Documenti richiesti", style: AppTextStyles.sectionTitle),
            SizedBox(height: 8),
            Text(
              "Atto costitutivo, Statuto, eventuale iscrizione (es. RUNTS) e documento del legale rappresentante.",
              style: AppTextStyles.body,
            ),
          ],
        );
      case UserRoleType.delegate:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: const [
            SizedBox(height: 16),
            Text("Documenti richiesti", style: AppTextStyles.sectionTitle),
            SizedBox(height: 8),
            Text(
              "Delega/lettera di incarico firmata + documento del delegante e del delegato.",
              style: AppTextStyles.body,
            ),
          ],
        );
    }
  }

  List<Widget> _roleUploads() {
    if (_roleType == null) return const [];

    switch (_roleType!) {
      case UserRoleType.owner:
        return [
          const SizedBox(height: 12),
          _uploadBox(label: "Carica Visura Camerale (PDF)"),
        ];
      case UserRoleType.association:
        return [
          const SizedBox(height: 12),
          _uploadBox(label: "Carica Atto costitutivo (PDF)"),
          const SizedBox(height: 12),
          _uploadBox(label: "Carica Statuto (PDF)"),
          const SizedBox(height: 12),
          _uploadBox(label: "Carica iscrizione (se presente) (PDF)"),
          const SizedBox(height: 12),
          _uploadBox(label: "Documento legale rappresentante (PDF)"),
        ];
      case UserRoleType.delegate:
        return [
          const SizedBox(height: 12),
          _uploadBox(label: "Carica delega/lettera incarico (PDF)"),
          const SizedBox(height: 12),
          _uploadBox(label: "Documento delegante (PDF)"),
          const SizedBox(height: 12),
          _uploadBox(label: "Documento delegato (PDF)"),
        ];
    }
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HivePhotosController(),
      child: Builder(
        builder: (context) {
          return BasePage(
            scrollable: false,
            headerTitle: "Registra attività",
            showBack: true,
            showHome: true,
            showProfile: true,
            showBell: false,
            showLogout: false,
            body: AppBodyLayout(
              children: [
                const Text(
                  "Registra una nuova attività",
                  style: AppTextStyles.sectionTitle,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 26),

                buildInputBox(
                  label: "Tipo di attività",
                  hiveKey: "tipo_attivita",
                ),
                const SizedBox(height: 14),

                buildInputBox(label: "Insegna attività", hiveKey: "insegna"),
                const SizedBox(height: 14),

                buildInputBox(
                  label: "Ragione sociale",
                  hiveKey: "ragione_sociale",
                ),
                const SizedBox(height: 14),

                buildInputBox(label: "Via", hiveKey: "via"),
                const SizedBox(height: 14),

                buildInputBox(label: "Paese", hiveKey: "paese"),
                const SizedBox(height: 14),

                buildInputBox(label: "Città", hiveKey: "citta"),
                const SizedBox(height: 14),

                buildInputBox(
                  label: "CAP",
                  hiveKey: "cap",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),

                buildInputBox(
                  label: "Telefono fisso o cellulare",
                  hiveKey: "telefono",
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 14),

                buildInputBox(
                  label: "P. IVA",
                  hiveKey: "piva",
                  keyboardType: TextInputType.number,
                ),
                const SizedBox(height: 14),

                buildInputBox(label: "Codice SDI", hiveKey: "sdi"),
                const SizedBox(height: 14),

                buildInputBox(
                  label: "PEC",
                  hiveKey: "pec",
                  keyboardType: TextInputType.emailAddress,
                ),
                const SizedBox(height: 14),

                buildInputBox(
                  label: "Mail",
                  hiveKey: "mail",
                  keyboardType: TextInputType.emailAddress,
                ),

                const SizedBox(height: 26),

                const Text(
                  "Foto attività (minimo 5, massimo 10)",
                  style: AppTextStyles.sectionTitle,
                ),
                const SizedBox(height: 6),

                const Text(
                  "Formati: JPG, JPEG, PNG — Min 1200px lato lungo — Min 800px altezza — Max 5MB",
                  style: AppTextStyles.body,
                ),

                const SizedBox(height: 16),

                Consumer<HivePhotosController>(
                  builder: (context, controller, _) {
                    return GridView.count(
                      shrinkWrap: true,
                      crossAxisCount: 2,
                      mainAxisSpacing: 14,
                      crossAxisSpacing: 14,
                      physics: const NeverScrollableScrollPhysics(),
                      children: [
                        for (final path in controller.photos)
                          PhotoPreview(
                            path: path,
                            onRemove: () => controller.removePhoto(path),
                          ),

                        if (controller.showAddBox)
                          AddPhotoBox(
                            onTap: () async {
                              String? result = await pickImage();

                              if (result != null) {
                                controller.addPhoto(result);
                              }
                            },
                          ),
                      ],
                    );
                  },
                ),

                const SizedBox(height: 26),

                const SizedBox(height: 34),

                const Text(
                  "Seleziona il tuo ruolo",
                  style: AppTextStyles.sectionTitle,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 18),

                Row(
                  children: [
                    Expanded(
                      child: _roleButton(
                        label: "Gestore / Libero professionista",
                        value: UserRoleType.owner,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _roleButton(
                        label: "Associazione/Ente",
                        value: UserRoleType.association,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _roleButton(
                        label: "Responsabile/Dipendente",
                        value: UserRoleType.delegate,
                      ),
                    ),
                  ],
                ),

                _roleDocuments(),
                ..._roleUploads(),

                const SizedBox(height: 34),
              ],
            ),
          );
        },
      ),
    );
  }
}
