import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

// Structured data model for help content (enables future localization & generation)
class HelpFeature {
  final IconData icon;
  final String title;
  final String description;
  const HelpFeature({required this.icon, required this.title, required this.description});
}

class HelpSectionModel {
  final String title;
  final String? description;
  final List<HelpFeature> features;
  const HelpSectionModel({required this.title, this.description, this.features = const []});
}

// Content extracted from previous static layout (mirrors markdown use cases)
const List<HelpSectionModel> _sections = [
  HelpSectionModel(
    title: 'Paneli Kryesor i Kontrollit',
    description: 'Ky është paneli që gjendet në krye të faqes kryesore dhe ju jep akses të shpejtë te funksionalitetet më të rëndësishme.',
    features: [
      HelpFeature(
        icon: Icons.search,
        title: 'Kërkimi Inteligjent',
        description: 'Fusha kryesore e kërkimit ju lejon të gjeni çdo gjë shpejt. Mund të kërkoni për: Emrin ose numrin e sures (p.sh., Fatiha ose 1), Një ajet specifik (p.sh., 2:255 për Ajetul Kursinë), Fjalë kyçe (p.sh., namazi, paqja, ose مُوسَىٰ).',
      ),
      HelpFeature(
        icon: Icons.filter_list,
        title: 'Filtrat e Kërkimit',
        description: 'Personalizoni kërkimin tuaj. Zgjidhni nëse doni të kërkoni në tekstin Shqip, Arabisht, ose të dyja. Gjithashtu, mund ta kufizoni kërkimin vetëm brenda një Xhuzi specifik.',
      ),
      HelpFeature(
        icon: Icons.language,
        title: 'Zgjedhja e Përkthimit',
        description: 'Zgjidhni midis përkthimeve të besueshme në gjuhën shqipe nga Sherif Ahmeti, Feti Mehdiu, dhe Efendi Nahi për të krahasuar dhe kuptuar më mirë tekstin.',
      ),
      HelpFeature(
        icon: Icons.compass_calibration,
        title: 'Lundrim i Shpejtë',
        description: 'Përdorni menunë "Shko te Xhuzi" për të lundruar menjëherë në fillimin e cilitdo prej 30 xhuzeve të Kuranit Fisnik.',
      ),
    ],
  ),
  HelpSectionModel(
    title: 'Kontrollet në Pamjen e Leximit',
    description: 'Kur hapni një sure për ta lexuar, një shirit kontrolli shfaqet në krye të faqes. Ky shirit ofron veprime specifike për atë sure.',
    features: [
      HelpFeature(
        icon: Icons.sort,
        title: 'Shko te Ajeti',
        description: 'Përdorni menunë rënëse për të kërcyer direkt te një ajet specifik brenda sures që po lexoni, pa pasur nevojë të bëni scroll.',
      ),
      HelpFeature(
        icon: Icons.check_box,
        title: 'Modaliteti i Përzgjedhjes',
        description: 'Aktivizoni këtë modalitet për të zgjedhur disa ajete njëkohësisht. Pasi të keni zgjedhur ajetet, një shirit veprimesh do të shfaqet në fund, duke ju lejuar t\'i kopjoni, ndani, ose t\'i shtoni te të preferuarat të gjitha njëherësh.',
      ),
      HelpFeature(
        icon: Icons.fullscreen,
        title: 'Lexim pa Shpërqendrime',
        description: 'Aktivizoni modalitetin "fullscreen" për të fshehur të gjithë elementet e tjerë të faqes dhe për t\'u fokusuar vetëm te teksti i Kuranit.',
      ),
      HelpFeature(
        icon: Icons.play_circle_fill,
        title: 'Luaj Gjithë Suren',
        description: 'Fillon luajtjen audio të të gjithë sures, ajet pas ajeti, pa ndërprerje. Klikimi përsëri e ndalon luajtjen.',
      ),
    ],
  ),
  HelpSectionModel(
    title: 'Veprimet Specifike për çdo Ajet',
    description: 'Poshtë çdo ajeti në pamjen e leximit, ju do të gjeni një sërë ikonash. Ja se çfarë bën secila prej tyre:',
    features: [
      HelpFeature(icon: Icons.play_arrow, title: 'Dëgjo', description: 'Luan recitimin audio të ajetit përkatës. Nëse e klikoni përsëri, e ndalon atë.'),
      HelpFeature(icon: Icons.favorite, title: 'Shto te të Preferuarat', description: 'E shton ajetin në listën tuaj personale te tabi "Të Preferuarat". Klikimi përsëri e heq atë.'),
      HelpFeature(icon: Icons.copy, title: 'Kopjo', description: 'Kopjon tekstin e ajetit (arabisht dhe shqip) bashkë me referencën, gati për ta ngjitur kudo që dëshironi.'),
      HelpFeature(icon: Icons.share, title: 'Ndaj', description: 'Hap menunë e ndarjes së pajisjes suaj për të dërguar një lidhje direkte drejt këtij ajeti te miqtë tuaj.'),
      HelpFeature(icon: Icons.bookmark, title: 'Shenjo', description: 'E ruan këtë ajet si pikën tuaj të fundit të leximit, të cilën mund ta gjeni te tabi "Shenjuesit".'),
      HelpFeature(icon: Icons.edit, title: 'Shënim', description: 'Hap një editor teksti ku mund të shkruani dhe të ruani shënimet dhe reflektimet tuaja personale për këtë ajet.'),
      HelpFeature(icon: Icons.psychology, title: 'Memorizo', description: 'E shton ajetin në listën tuaj te tabi "Memorizim" për t\'ju ndihmuar në procesin e mësimit përmendësh.'),
      HelpFeature(icon: Icons.image, title: 'Gjenero Imazh', description: 'Hap një panel të fuqishëm ku mund të krijoni një imazh të bukur dhe të personalizuar të ajetit, gati për ta shkarkuar ose shpërndarë në rrjetet sociale.'),
    ],
  ),
  HelpSectionModel(
    title: 'Shpjegimi i Seksioneve (Tab-eve)',
    features: [
      HelpFeature(icon: Icons.book, title: 'Kurani', description: 'Këtu gjendet zemra e aplikacionit. Fillimisht shfaqet lista e plotë e 114 sureve. Duke klikuar mbi një sure, ju kaloni në pamjen e leximit, ku mund të lexoni tekstin arabisht, përkthimin dhe transliterimin.'),
      HelpFeature(icon: Icons.category, title: 'Indeksi Tematik', description: 'Një mjet i fuqishëm për studim, i cili i grupon ajetet e Kuranit sipas temave kryesore që ato trajtojnë. Zgjidhni një kategori dhe një nën-temë për të parë të gjitha ajetet përkatëse.'),
      HelpFeature(icon: Icons.school, title: 'Texhvid', description: 'Mësoni rregullat e leximit të saktë të Kuranit. Ky seksion ofron shpjegime të detajuara dhe shembuj për çdo rregull. Gjithashtu, mund të testoni njohuritë tuaja me kuize interaktive.'),
      HelpFeature(icon: Icons.favorite, title: 'Të Preferuarat', description: 'Këtu ruhen të gjitha ajetet që keni shënuar si të preferuara. Është koleksioni juaj personal i ajeteve që ju kanë prekur më shumë, lehtësisht i aksesueshëm.'),
      HelpFeature(icon: Icons.psychology, title: 'Memorizim', description: 'Një hapësirë e dedikuar për t\'ju ndihmuar të mësoni përmendësh ajete. Shtoni ajete në këtë listë dhe përdorni veglat si fshehja e tekstit dhe përsëritja e audios për të praktikuar.'),
      HelpFeature(icon: Icons.bookmark, title: 'Shenjuesit', description: 'Ky seksion ruan vendin e fundit ku keni vendosur një shenjues. Shërben si një pikë referimi e shpejtë për të vazhduar leximin ose studimin aty ku e keni lënë.'),
      HelpFeature(icon: Icons.edit_note, title: 'Shënimet', description: 'Të gjitha shënimet dhe reflektimet tuaja personale që keni mbajtur për ajete të ndryshme grupohen këtu. Mund t\'i kërkoni dhe t\'i filtroni lehtësisht.'),
    ],
  ),
  HelpSectionModel(
    title: 'Shpjegimi i Impostimeve',
    description: 'Paneli i cilësimeve, i cili hapet duke klikuar ikonën, ju jep kontroll të plotë mbi pamjen dhe funksionimin e aplikacionit.',
    features: [
      HelpFeature(icon: Icons.palette, title: 'Tema', description: 'Zgjidhni midis temave të ndryshme vizuale (e ndritshme, e errët, sepia, mesnatë) për të personalizuar pamjen e aplikacionit.'),
      HelpFeature(icon: Icons.text_fields, title: 'Madhësia e shkronjave', description: 'Rregulloni madhësinë e shkronjave për tekstin arabisht dhe përkthimin sipas preferencave tuaja.'),
      HelpFeature(icon: Icons.translate, title: 'Përkthimi', description: 'Zgjidhni përkthimin e preferuar të Kuranit në gjuhën shqipe.'),
      HelpFeature(icon: Icons.visibility, title: 'Opsionet e shfaqjes', description: 'Kontrolloni shfaqjen e tekstit arabisht, përkthimit, transliterimit dhe leximit fjalë për fjalë.'),
    ],
  ),
];

class HelpPage extends StatelessWidget {
  const HelpPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Ndihmë',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        foregroundColor: Theme.of(context).colorScheme.onPrimaryContainer,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(AppSpacing.lg),
        itemCount: _sections.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              child: _buildHeader(context),
            );
          }
          final section = _sections[index - 1];
            return Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xxxl),
              child: _buildSection(context,
                title: section.title,
                description: section.description,
                features: section.features
                    .map((f) => _buildFeatureItem(context, icon: f.icon, title: f.title, description: f.description))
                    .toList(),
              ),
            );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16.0),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Theme.of(context).colorScheme.primary, Theme.of(context).colorScheme.primaryContainer],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Text(
            'Udhëzues i Plotë',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary,
              fontWeight: FontWeight.bold,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Gjithçka që duhet të dini për të shfrytëzuar platformën "Kurani Fisnik Online"',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onPrimary.withOpacity(0.8),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildSection(BuildContext context, {required String title, String? description, required List<Widget> features}) {
    return Card(
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadii.card.x)),
      child: Padding(
        padding: AppInsets.cardContent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            if (description != null) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                description,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            const SizedBox(height: AppSpacing.lg),
            ...features,
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureItem(BuildContext context, {required IconData icon, required String title, required String description}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 24),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: AppSpacing.xs),
                Text(
                  description,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}


