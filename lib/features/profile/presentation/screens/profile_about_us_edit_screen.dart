import 'package:flutter/material.dart';
import 'dart:ui';
import 'package:image_picker/image_picker.dart';
import '../../../../core/theme/app_theme.dart';
import '../../auth/domain/repositories/profile_repository.dart';

class ProfileAboutUsEditScreen extends StatefulWidget {
  const ProfileAboutUsEditScreen({super.key});

  @override
  State<ProfileAboutUsEditScreen> createState() => _ProfileAboutUsEditScreenState();
}

class _ProfileAboutUsEditScreenState extends State<ProfileAboutUsEditScreen> {
  final ProfileRepository _repo = ProfileRepository();
  bool _isLoading = true;
  bool _isSaving = false;

  int yearsOfExperience = 0;
  final ImagePicker _picker = ImagePicker();
  
  bool _isUploadingLogo = false;
  String? _uploadedLogoUrl;
  
  bool _isUploadingGallery = false;
  final List<String> _galleryPhotos = []; 
  
  final List<String> _specialties = ['Bodas', 'Eventos Corporativos', 'Rosas', 'Mayoreo', 'Arreglos Florales'];
  final Set<String> _selectedSpecialties = {};

  final List<MilestoneData> _milestones = [];
  
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _newMilestoneYearCtrl = TextEditingController();
  final TextEditingController _newMilestoneTitleCtrl = TextEditingController();
  final TextEditingController _newMilestoneDescCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadProfileData();
  }

  Future<void> _loadProfileData() async {
    try {
      final data = await _repo.getProfile();
      if (data != null) {
        setState(() {
          _uploadedLogoUrl = data['logo_url'];
          _bioController.text = data['biography'] ?? '';
          yearsOfExperience = data['years_of_experience'] ?? 0;
          
          if (data['specialties'] != null) {
            final specs = List<String>.from(data['specialties']);
            _selectedSpecialties.addAll(specs);
            for (var s in specs) {
              if (!_specialties.contains(s)) _specialties.add(s);
            }
          }
          
          if (data['milestones'] != null) {
             final ms = List<Map<String,dynamic>>.from(data['milestones']);
             _milestones.addAll(ms.map((m) => MilestoneData(year: m['year'] ?? '', title: m['title'] ?? '', description: m['description'] ?? '')));
          }

          if (data['gallery'] != null) {
             _galleryPhotos.addAll(List<String>.from(data['gallery']));
          }
        });
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _bioController.dispose();
    _newMilestoneYearCtrl.dispose();
    _newMilestoneTitleCtrl.dispose();
    _newMilestoneDescCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundLight,
      appBar: AppBar(
        title: const Text('Nosotros', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
        centerTitle: true,
        backgroundColor: AppTheme.cardLight,
        elevation: 0,
        scrolledUnderElevation: 2,
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: AppTheme.primary))
        : Stack(
        children: [
          SingleChildScrollView(
            padding: const EdgeInsets.only(left: 24, right: 24, top: 24, bottom: 120),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSectionHeader('Imagen de Identidad', Icons.image, Colors.purple),
                _buildIdentityImageUpload(),
                const SizedBox(height: 32),
                
                _buildSectionHeader('Biografía del Negocio', Icons.history_edu, Colors.purple),
                _buildBiographyField(),
                const SizedBox(height: 32),

                _buildSectionHeader('Años de Experiencia', Icons.hourglass_top, Colors.purple),
                _buildExperienceCounter(),
                const SizedBox(height: 32),

                _buildSectionHeader('Especialidades', Icons.verified, Colors.purple),
                _buildSpecialtiesCards(),
                const SizedBox(height: 32),

                _buildSectionHeader('Nuestra Trayectoria', Icons.trending_up, Colors.purple),
                _buildTrajectoryEditor(),
                const SizedBox(height: 32),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildSectionHeader('Galería de Fotos', Icons.collections, Colors.purple),
                    const Text('2/6', style: TextStyle(color: AppTheme.mutedLight, fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                const Padding(
                  padding: EdgeInsets.only(bottom: 16.0),
                  child: Text('Sube fotos de alta calidad de tu trabajo o instalaciones.', style: TextStyle(color: AppTheme.mutedLight, fontSize: 13)),
                ),
                _buildPhotoGallery(),
              ],
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.bottomCenter,
                  end: Alignment.topCenter,
                  colors: [
                    AppTheme.backgroundLight,
                    AppTheme.backgroundLight.withValues(alpha: 0.9),
                    AppTheme.backgroundLight.withValues(alpha: 0),
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: _isSaving ? null : () async {
                  setState(() => _isSaving = true);
                  try {
                    final milestonesData = _milestones.map((m) => {
                      'year': m.year,
                      'title': m.title,
                      'description': m.description,
                    }).toList();

                    await _repo.updateProfile(
                      logoUrl: _uploadedLogoUrl,
                      biography: _bioController.text,
                      yearsOfExperience: yearsOfExperience,
                      specialties: _selectedSpecialties.toList(),
                      milestones: milestonesData,
                      gallery: _galleryPhotos,
                    );
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Información guardada exitosamente'), backgroundColor: Colors.green));
                      Navigator.pop(context);
                    }
                  } catch (e) {
                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error al guardar: $e'), backgroundColor: Colors.red));
                  } finally {
                    if (mounted) setState(() => _isSaving = false);
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 4,
                  shadowColor: AppTheme.primary.withValues(alpha: 0.3),
                ),
                child: _isSaving
                    ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('Guardar cambios', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, Color iconColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Icon(icon, color: iconColor, size: 22),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: AppTheme.textLight,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildIdentityImageUpload() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          GestureDetector(
            onTap: () async {
              if (_isUploadingLogo) return;
              
              try {
                final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
                if (image != null) {
                  setState(() => _isUploadingLogo = true);
                  final url = await _repo.uploadLogo(image);
                  setState(() {
                    if (url != null) _uploadedLogoUrl = url;
                    _isUploadingLogo = false;
                  });
                }
              } catch (e) {
                setState(() => _isUploadingLogo = false);
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error subiendo imagen: $e')));
              }
            },
            child: Container(
              width: 120,
              height: 120,
              decoration: BoxDecoration(
                color: AppTheme.backgroundLight,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.none),
                image: _uploadedLogoUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(_uploadedLogoUrl!), 
                        fit: BoxFit.cover,
                      )
                    : null,
              ),
              child: _uploadedLogoUrl != null 
                  ? null // If we have an image, don't show the inner lines
                  : CustomPaint(
                      painter: DashedRectPainter(color: Colors.grey.withValues(alpha: 0.5), strokeWidth: 2, radius: 20),
                      child: Center(
                        child: _isUploadingLogo 
                            ? const CircularProgressIndicator(color: Colors.purple)
                            : const Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add_photo_alternate, color: AppTheme.mutedLight, size: 36),
                    SizedBox(height: 8),
                    Text('Subir logo', style: TextStyle(color: AppTheme.mutedLight, fontSize: 12, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Sube una imagen cuadrada que represente la esencia de tu marca.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppTheme.mutedLight, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildBiographyField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          children: [
            TextFormField(
              controller: _bioController,
              maxLines: 5,
              style: const TextStyle(fontSize: 14, color: AppTheme.textLight),
              decoration: InputDecoration(
                hintText: 'Cuéntanos la historia de tu florería, tus orígenes y lo que te hace único en el mercado...',
                hintStyle: const TextStyle(color: AppTheme.mutedLight),
                filled: true,
                fillColor: Colors.white,
                contentPadding: const EdgeInsets.all(16),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.2)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(20),
                  borderSide: const BorderSide(color: Colors.purple, width: 2),
                ),
              ),
            ),
            const Positioned(
              bottom: 12,
              right: 16,
              child: Text('0/500', style: TextStyle(color: AppTheme.mutedLight, fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Padding(
          padding: EdgeInsets.only(left: 4.0),
          child: Text('Esta descripción aparecerá en la parte superior de tu perfil público.', style: TextStyle(color: AppTheme.mutedLight, fontSize: 12)),
        ),
      ],
    );
  }

  Widget _buildExperienceCounter() {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: const Icon(Icons.remove, color: Colors.purple),
              onPressed: () {
                if (yearsOfExperience > 0) {
                  setState(() {
                    yearsOfExperience--;
                  });
                }
              },
            ),
          ),
          Text('$yearsOfExperience', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppTheme.textLight)),
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.purple),
              onPressed: () {
                setState(() {
                  yearsOfExperience++;
                });
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSpecialtiesCards() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ..._specialties.map((spec) => _buildChip(spec)),
        ActionChip(
          label: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.add, size: 16, color: AppTheme.mutedLight),
              SizedBox(width: 4),
              Text('Agregar', style: TextStyle(color: AppTheme.mutedLight, fontWeight: FontWeight.bold)),
            ],
          ),
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid), // Replaced dashed with solid for simplicity for now
          ),
          onPressed: _showAddSpecialtyDialog,
        ),
      ],
    );
  }

  Widget _buildChip(String label) {
    bool isSelected = _selectedSpecialties.contains(label);
    return FilterChip(
      label: Text(label, style: TextStyle(color: isSelected ? Colors.white : AppTheme.textLight, fontWeight: FontWeight.bold, fontSize: 13)),
      selected: isSelected,
      onSelected: (bool selected) {
        setState(() {
          if (selected) {
            _selectedSpecialties.add(label);
          } else {
            _selectedSpecialties.remove(label);
          }
        });
      },
      selectedColor: Colors.purple,
      backgroundColor: Colors.white,
      showCheckmark: false,
      side: BorderSide(color: isSelected ? Colors.transparent : Colors.grey.withValues(alpha: 0.2)),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
    );
  }

  void _showAddSpecialtyDialog() {
    String newSpecialty = '';
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Agregar Especialidad'),
          content: TextField(
            autofocus: true,
            decoration: const InputDecoration(hintText: 'Ej. Tulipanes, Envíos Express'),
            onChanged: (val) => newSpecialty = val,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              onPressed: () {
                if (newSpecialty.trim().isNotEmpty) {
                  setState(() {
                    _specialties.add(newSpecialty.trim());
                    _selectedSpecialties.add(newSpecialty.trim());
                  });
                }
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.purple, foregroundColor: Colors.white),
              child: const Text('Agregar'),
            ),
          ],
        );
      },
    );
  }

  Widget _buildTrajectoryEditor() {
    return Column(
      children: [
        // Existing Milestones
        ..._milestones.asMap().entries.map((entry) {
          int idx = entry.key;
          MilestoneData milestone = entry.value;
          return Container(
            padding: const EdgeInsets.all(16),
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(), // Spacer
                     IconButton(
                      icon: const Icon(Icons.close, color: Colors.grey, size: 20),
                      onPressed: () {
                        setState(() {
                          _milestones.removeAt(idx);
                        });
                      },
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
                Row(
                  children: [
                    Expanded(
                      flex: 1,
                      child: _buildSmallTextField('Año', milestone.year, onChanged: (v) => milestone.year = v),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: _buildSmallTextField('Título', milestone.title, onChanged: (v) => milestone.title = v),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                const Padding(
                  padding: EdgeInsets.only(left: 4.0, bottom: 4.0),
                  child: Text('Descripción breve', style: TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
                ),
                TextFormField(
                  initialValue: milestone.description,
                  onChanged: (v) => milestone.description = v,
                  maxLines: 2,
                  style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppTheme.backgroundLight,
                    contentPadding: const EdgeInsets.all(12),
                     border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                    ),
                     focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: Colors.purple, width: 1.5),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Add new milestone form
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.withValues(alpha: 0.3), style: BorderStyle.solid), // Should be dashed if possible via painter
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    flex: 1,
                    child: _buildSmallTextFieldController('Año', _newMilestoneYearCtrl, hint: 'Ej. 2020'),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: _buildSmallTextFieldController('Título', _newMilestoneTitleCtrl, hint: 'Ej. Expansión'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              const Padding(
                padding: EdgeInsets.only(left: 4.0, bottom: 4.0),
                child: Text('Descripción breve', style: TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
              ),
              TextFormField(
                controller: _newMilestoneDescCtrl,
                maxLines: 2,
                style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
                decoration: InputDecoration(
                  hintText: 'Describe brevemente este hito importante...',
                  hintStyle: const TextStyle(color: AppTheme.mutedLight, fontSize: 13),
                  filled: true,
                  fillColor: AppTheme.backgroundLight,
                  contentPadding: const EdgeInsets.all(12),
                   border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
                  ),
                   focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: Colors.purple, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: TextButton.icon(
                  onPressed: () {
                    final year = _newMilestoneYearCtrl.text.trim();
                    final title = _newMilestoneTitleCtrl.text.trim();
                    if (year.isEmpty || title.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Por favor llena el Año y el Título antes de agregar.'),
                          backgroundColor: Colors.purple,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                      return;
                    }
                    setState(() {
                      _milestones.add(MilestoneData(
                        year: year,
                        title: title,
                        description: _newMilestoneDescCtrl.text.trim(),
                      ));
                      _newMilestoneYearCtrl.clear();
                      _newMilestoneTitleCtrl.clear();
                      _newMilestoneDescCtrl.clear();
                    });
                  },
                  icon: const Icon(Icons.add_circle, color: Colors.purple, size: 20),
                  label: const Text('Agregar Hito', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple)),
                  style: TextButton.styleFrom(
                    backgroundColor: Colors.purple.withValues(alpha: 0.05),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.purple.withValues(alpha: 0.2)),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSmallTextFieldController(String label, TextEditingController controller, {String? hint}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
        ),
        TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.mutedLight, fontSize: 13),
            filled: true,
            fillColor: AppTheme.backgroundLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.purple, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSmallTextField(String label, String initialValue, {String? hint, Function(String)? onChanged}) {

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4.0, bottom: 4.0),
          child: Text(label, style: const TextStyle(fontSize: 12, color: AppTheme.mutedLight)),
        ),
        TextFormField(
          initialValue: initialValue.isNotEmpty ? initialValue : null,
          onChanged: onChanged,
          style: const TextStyle(fontSize: 13, color: AppTheme.textLight),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: AppTheme.mutedLight, fontSize: 13),
            filled: true,
            fillColor: AppTheme.backgroundLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.grey.withValues(alpha: 0.1)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Colors.purple, width: 1.5),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPhotoGallery() {
    return GridView.count(
      crossAxisCount: 3,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        // Upload Button
        GestureDetector(
          onTap: () async {
            if (_isUploadingGallery) return;
            
            try {
               final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
               if (image != null) {
                 setState(() => _isUploadingGallery = true);
                 final url = await _repo.uploadImage(image, folder: 'gallery');
                 setState(() {
                    if (url != null) _galleryPhotos.add(url);
                    _isUploadingGallery = false;
                 });
               }
            } catch (e) {
               setState(() => _isUploadingGallery = false);
               if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: Colors.purple.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.4), style: BorderStyle.solid), // Dashed normally
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _isUploadingGallery 
                    ? const CircularProgressIndicator(color: Colors.purple)
                    : const CircleAvatar(
                        backgroundColor: Colors.purple,
                        radius: 16,
                        child: Icon(Icons.add_a_photo, color: Colors.white, size: 16),
                      ),
                const SizedBox(height: 4),
                Text(_isUploadingGallery ? 'Subiendo...' : 'Subir', style: const TextStyle(color: Colors.purple, fontWeight: FontWeight.bold, fontSize: 12)),
              ],
            ),
          ),
        ),
        
        // Photos generated from list
        ..._galleryPhotos.asMap().entries.map((entry) {
          int idx = entry.key;
          String photoUrl = entry.value;

          return ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(photoUrl, fit: BoxFit.cover),
                 Positioned(
                  top: 4,
                  right: 4,
                  child: GestureDetector(
                    onTap: () {
                      setState(() {
                        _galleryPhotos.removeAt(idx);
                      });
                    },
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.5), shape: BoxShape.circle),
                      child: const Icon(Icons.close, color: Colors.white, size: 14),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),

        // Empty Slots based on 6 max
        for(int i = 0; i < (5 - _galleryPhotos.length); i++)
          Container(
            decoration: BoxDecoration(
              color: AppTheme.backgroundLight,
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Center(
              child: Icon(Icons.image, color: Colors.black12, size: 32),
            ),
          ),
      ],
    );
  }
}

// Helper specific to Dashed border
class DashedRectPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final double gap;
  final double radius;

  DashedRectPainter({this.color = Colors.black, this.strokeWidth = 1.0, this.gap = 5.0, this.radius = 0.0});

  @override
  void paint(Canvas canvas, Size size) {
    var paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    var path = Path();
    path.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 0, size.width, size.height), Radius.circular(radius)));

    Path dashPath = Path();
    double distance = 0.0;
    for (PathMetric pathMetric in path.computeMetrics()) {
      while (distance < pathMetric.length) {
        dashPath.addPath(pathMetric.extractPath(distance, distance + gap), Offset.zero);
        distance += gap * 2;
      }
    }
    canvas.drawPath(dashPath, paint);
  }

  @override
  bool shouldRepaint(CustomPainter oldDelegate) => false;
}

class MilestoneData {
  String year;
  String title;
  String description;
  MilestoneData({required this.year, required this.title, required this.description});
}
