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

class RegisterActivityPage extends StatelessWidget {
  const RegisterActivityPage({super.key});

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
        decoration: InputDecoration(
          labelText: label,
          border: InputBorder.none,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HivePhotosController(),
      child: Builder(
        builder: (context) {
          return BasePage(
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

                buildInputBox(label: "Tipo di attività", hiveKey: "tipo_attivita"),
                const SizedBox(height: 14),

                buildInputBox(label: "Insegna attività", hiveKey: "insegna"),
                const SizedBox(height: 14),

                buildInputBox(label: "Ragione sociale", hiveKey: "ragione_sociale"),
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

                GestureDetector(
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
                        const Expanded(
                          child: Text(
                            "Carica Visura Camerale (PDF)",
                            style: AppTextStyles.body,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 34),

                // ---------------------------------------------------------
                // NUOVA SEZIONE: Sei il gestore?
                // ---------------------------------------------------------
                const Text(
                  "Sei il gestore, presidente o responsabile dell’attività?",
                  style: AppTextStyles.sectionTitle,
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Center(
                          child: Text(
                            "Sì",
                            style: AppTextStyles.body,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: const Center(
                          child: Text(
                            "No",
                            style: AppTextStyles.body,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 34),
                // ---------------------------------------------------------
              ],
            ),
          );
        },
      ),
    );
  }
}