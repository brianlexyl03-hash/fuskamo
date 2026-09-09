/// Static category data — NOT personal data, so unlike Player/Scout it's
/// fine to define directly in code (same as the original web app's REGIONS
/// array). `countries` drives the actual Supabase filter in
/// RegionDetailScreen — tapping a region queries `players` for anyone
/// whose `country` is in this list, since the players table has no
/// separate `region` column of its own.
class Region {
  final String name;
  final String flagEmoji;
  final List<String> countries;

  const Region({required this.name, required this.flagEmoji, required this.countries});

  static const List<Region> all = [
    Region(
      name: 'West Africa',
      flagEmoji: '🌍',
      countries: [
        'Nigeria', 'Ghana', 'Senegal', 'Ivory Coast', "Cote d'Ivoire", 'Mali',
        'Guinea', 'Burkina Faso', 'Benin', 'Togo', 'Sierra Leone', 'Liberia',
        'Gambia', 'Guinea-Bissau', 'Niger', 'Cape Verde', 'Mauritania',
      ],
    ),
    Region(
      name: 'East Africa',
      flagEmoji: '🌍',
      countries: [
        'Kenya', 'Tanzania', 'Uganda', 'Ethiopia', 'Rwanda', 'Burundi',
        'South Sudan', 'Somalia', 'Djibouti', 'Eritrea',
      ],
    ),
    Region(
      name: 'North Africa',
      flagEmoji: '🌍',
      countries: ['Egypt', 'Morocco', 'Algeria', 'Tunisia', 'Libya', 'Sudan'],
    ),
    Region(
      name: 'Southern Africa',
      flagEmoji: '🌍',
      countries: [
        'South Africa', 'Zambia', 'Zimbabwe', 'Mozambique', 'Botswana',
        'Namibia', 'Malawi', 'Lesotho', 'Eswatini', 'Angola',
      ],
    ),
    Region(
      name: 'South America',
      flagEmoji: '🌎',
      countries: [
        'Brazil', 'Argentina', 'Uruguay', 'Colombia', 'Chile', 'Ecuador',
        'Peru', 'Paraguay', 'Bolivia', 'Venezuela',
      ],
    ),
    Region(
      name: 'Asia',
      flagEmoji: '🌏',
      countries: [
        'Japan', 'South Korea', 'China', 'India', 'Indonesia', 'Iran',
        'Saudi Arabia', 'Qatar', 'Thailand', 'Vietnam', 'Uzbekistan',
      ],
    ),
    Region(
      name: 'Central Africa',
      flagEmoji: '🌍',
      countries: [
        'Cameroon', 'DR Congo', 'Congo', 'Gabon', 'Chad',
        'Central African Republic', 'Equatorial Guinea',
      ],
    ),
    Region(
      name: 'Caribbean',
      flagEmoji: '🌎',
      countries: [
        'Jamaica', 'Trinidad and Tobago', 'Haiti', 'Dominican Republic',
        'Cuba', 'Bahamas',
      ],
    ),
  ];
}
