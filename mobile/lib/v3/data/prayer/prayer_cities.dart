/// Bundled city coordinates for prayer times.
///
/// A city-sized fix is more than accurate enough: moving 20km changes the
/// computed times by well under a minute. Bundling them means the default
/// setup path needs no location permission, no GPS wake-up and no network
/// call — which is what keeps the feature free at rest.
///
/// Weighted towards India and the Gulf, where this app's families are.
class PrayerCity {
  final String id;
  final String name;
  final String region;
  final double lat;
  final double lng;

  const PrayerCity(this.id, this.name, this.region, this.lat, this.lng);

  String get label => '$name, $region';
}

class PrayerCities {
  PrayerCities._();

  static const List<PrayerCity> all = [
    // ── India ───────────────────────────────────────────────────────────────
    PrayerCity('in-kochi', 'Kochi', 'Kerala', 9.9312, 76.2673),
    PrayerCity('in-tvm', 'Thiruvananthapuram', 'Kerala', 8.5241, 76.9366),
    PrayerCity('in-kozhikode', 'Kozhikode', 'Kerala', 11.2588, 75.7804),
    PrayerCity('in-thrissur', 'Thrissur', 'Kerala', 10.5276, 76.2144),
    PrayerCity('in-kannur', 'Kannur', 'Kerala', 11.8745, 75.3704),
    PrayerCity('in-kollam', 'Kollam', 'Kerala', 8.8932, 76.6141),
    PrayerCity('in-alappuzha', 'Alappuzha', 'Kerala', 9.4981, 76.3388),
    PrayerCity('in-malappuram', 'Malappuram', 'Kerala', 11.0510, 76.0711),
    PrayerCity('in-palakkad', 'Palakkad', 'Kerala', 10.7867, 76.6548),
    PrayerCity('in-kottayam', 'Kottayam', 'Kerala', 9.5916, 76.5222),
    PrayerCity('in-kasaragod', 'Kasaragod', 'Kerala', 12.4996, 74.9869),
    PrayerCity('in-bengaluru', 'Bengaluru', 'Karnataka', 12.9716, 77.5946),
    PrayerCity('in-mangaluru', 'Mangaluru', 'Karnataka', 12.9141, 74.8560),
    PrayerCity('in-mysuru', 'Mysuru', 'Karnataka', 12.2958, 76.6394),
    PrayerCity('in-hubballi', 'Hubballi', 'Karnataka', 15.3647, 75.1240),
    PrayerCity('in-chennai', 'Chennai', 'Tamil Nadu', 13.0827, 80.2707),
    PrayerCity('in-coimbatore', 'Coimbatore', 'Tamil Nadu', 11.0168, 76.9558),
    PrayerCity('in-madurai', 'Madurai', 'Tamil Nadu', 9.9252, 78.1198),
    PrayerCity('in-trichy', 'Tiruchirappalli', 'Tamil Nadu', 10.7905, 78.7047),
    PrayerCity('in-salem', 'Salem', 'Tamil Nadu', 11.6643, 78.1460),
    PrayerCity('in-hyderabad', 'Hyderabad', 'Telangana', 17.3850, 78.4867),
    PrayerCity('in-warangal', 'Warangal', 'Telangana', 17.9689, 79.5941),
    PrayerCity('in-vijayawada', 'Vijayawada', 'Andhra Pradesh', 16.5062, 80.6480),
    PrayerCity('in-vizag', 'Visakhapatnam', 'Andhra Pradesh', 17.6868, 83.2185),
    PrayerCity('in-tirupati', 'Tirupati', 'Andhra Pradesh', 13.6288, 79.4192),
    PrayerCity('in-mumbai', 'Mumbai', 'Maharashtra', 19.0760, 72.8777),
    PrayerCity('in-pune', 'Pune', 'Maharashtra', 18.5204, 73.8567),
    PrayerCity('in-nagpur', 'Nagpur', 'Maharashtra', 21.1458, 79.0882),
    PrayerCity('in-nashik', 'Nashik', 'Maharashtra', 19.9975, 73.7898),
    PrayerCity('in-sambhajinagar', 'Chhatrapati Sambhajinagar', 'Maharashtra',
        19.8762, 75.3433),
    PrayerCity('in-solapur', 'Solapur', 'Maharashtra', 17.6599, 75.9064),
    PrayerCity('in-delhi', 'New Delhi', 'Delhi', 28.6139, 77.2090),
    PrayerCity('in-gurugram', 'Gurugram', 'Haryana', 28.4595, 77.0266),
    PrayerCity('in-noida', 'Noida', 'Uttar Pradesh', 28.5355, 77.3910),
    PrayerCity('in-lucknow', 'Lucknow', 'Uttar Pradesh', 26.8467, 80.9462),
    PrayerCity('in-kanpur', 'Kanpur', 'Uttar Pradesh', 26.4499, 80.3319),
    PrayerCity('in-varanasi', 'Varanasi', 'Uttar Pradesh', 25.3176, 82.9739),
    PrayerCity('in-agra', 'Agra', 'Uttar Pradesh', 27.1767, 78.0081),
    PrayerCity('in-aligarh', 'Aligarh', 'Uttar Pradesh', 27.8974, 78.0880),
    PrayerCity('in-meerut', 'Meerut', 'Uttar Pradesh', 28.9845, 77.7064),
    PrayerCity('in-bareilly', 'Bareilly', 'Uttar Pradesh', 28.3670, 79.4304),
    PrayerCity('in-gorakhpur', 'Gorakhpur', 'Uttar Pradesh', 26.7606, 83.3732),
    PrayerCity('in-jaipur', 'Jaipur', 'Rajasthan', 26.9124, 75.7873),
    PrayerCity('in-jodhpur', 'Jodhpur', 'Rajasthan', 26.2389, 73.0243),
    PrayerCity('in-udaipur', 'Udaipur', 'Rajasthan', 24.5854, 73.7125),
    PrayerCity('in-ahmedabad', 'Ahmedabad', 'Gujarat', 23.0225, 72.5714),
    PrayerCity('in-surat', 'Surat', 'Gujarat', 21.1702, 72.8311),
    PrayerCity('in-vadodara', 'Vadodara', 'Gujarat', 22.3072, 73.1812),
    PrayerCity('in-rajkot', 'Rajkot', 'Gujarat', 22.3039, 70.8022),
    PrayerCity('in-bhavnagar', 'Bhavnagar', 'Gujarat', 21.7645, 72.1519),
    PrayerCity('in-kolkata', 'Kolkata', 'West Bengal', 22.5726, 88.3639),
    PrayerCity('in-howrah', 'Howrah', 'West Bengal', 22.5958, 88.2636),
    PrayerCity('in-siliguri', 'Siliguri', 'West Bengal', 26.7271, 88.3953),
    PrayerCity('in-patna', 'Patna', 'Bihar', 25.5941, 85.1376),
    PrayerCity('in-gaya', 'Gaya', 'Bihar', 24.7955, 84.9994),
    PrayerCity('in-bhopal', 'Bhopal', 'Madhya Pradesh', 23.2599, 77.4126),
    PrayerCity('in-indore', 'Indore', 'Madhya Pradesh', 22.7196, 75.8577),
    PrayerCity('in-jabalpur', 'Jabalpur', 'Madhya Pradesh', 23.1815, 79.9864),
    PrayerCity('in-ranchi', 'Ranchi', 'Jharkhand', 23.3441, 85.3096),
    PrayerCity('in-jamshedpur', 'Jamshedpur', 'Jharkhand', 22.8046, 86.2029),
    PrayerCity('in-bhubaneswar', 'Bhubaneswar', 'Odisha', 20.2961, 85.8245),
    PrayerCity('in-cuttack', 'Cuttack', 'Odisha', 20.4625, 85.8830),
    PrayerCity('in-raipur', 'Raipur', 'Chhattisgarh', 21.2514, 81.6296),
    PrayerCity('in-chandigarh', 'Chandigarh', 'Chandigarh', 30.7333, 76.7794),
    PrayerCity('in-ludhiana', 'Ludhiana', 'Punjab', 30.9010, 75.8573),
    PrayerCity('in-amritsar', 'Amritsar', 'Punjab', 31.6340, 74.8723),
    PrayerCity('in-srinagar', 'Srinagar', 'Jammu & Kashmir', 34.0837, 74.7973),
    PrayerCity('in-jammu', 'Jammu', 'Jammu & Kashmir', 32.7266, 74.8570),
    PrayerCity('in-dehradun', 'Dehradun', 'Uttarakhand', 30.3165, 78.0322),
    PrayerCity('in-shimla', 'Shimla', 'Himachal Pradesh', 31.1048, 77.1734),
    PrayerCity('in-guwahati', 'Guwahati', 'Assam', 26.1445, 91.7362),
    PrayerCity('in-silchar', 'Silchar', 'Assam', 24.8333, 92.7789),
    PrayerCity('in-imphal', 'Imphal', 'Manipur', 24.8170, 93.9368),
    PrayerCity('in-panaji', 'Panaji', 'Goa', 15.4909, 73.8278),
    PrayerCity('in-portblair', 'Port Blair', 'Andaman & Nicobar', 11.6234, 92.7265),

    // ── Gulf ────────────────────────────────────────────────────────────────
    PrayerCity('sa-makkah', 'Makkah', 'Saudi Arabia', 21.4225, 39.8262),
    PrayerCity('sa-madinah', 'Madinah', 'Saudi Arabia', 24.5247, 39.5692),
    PrayerCity('sa-riyadh', 'Riyadh', 'Saudi Arabia', 24.7136, 46.6753),
    PrayerCity('sa-jeddah', 'Jeddah', 'Saudi Arabia', 21.4858, 39.1925),
    PrayerCity('sa-dammam', 'Dammam', 'Saudi Arabia', 26.3927, 49.9777),
    PrayerCity('sa-khobar', 'Al Khobar', 'Saudi Arabia', 26.2794, 50.2083),
    PrayerCity('sa-abha', 'Abha', 'Saudi Arabia', 18.2164, 42.5053),
    PrayerCity('ae-dubai', 'Dubai', 'UAE', 25.2048, 55.2708),
    PrayerCity('ae-abudhabi', 'Abu Dhabi', 'UAE', 24.4539, 54.3773),
    PrayerCity('ae-sharjah', 'Sharjah', 'UAE', 25.3463, 55.4209),
    PrayerCity('ae-ajman', 'Ajman', 'UAE', 25.4052, 55.5136),
    PrayerCity('ae-rak', 'Ras Al Khaimah', 'UAE', 25.7895, 55.9432),
    PrayerCity('ae-fujairah', 'Fujairah', 'UAE', 25.1288, 56.3265),
    PrayerCity('ae-alain', 'Al Ain', 'UAE', 24.1302, 55.8023),
    PrayerCity('qa-doha', 'Doha', 'Qatar', 25.2854, 51.5310),
    PrayerCity('kw-kuwait', 'Kuwait City', 'Kuwait', 29.3759, 47.9774),
    PrayerCity('bh-manama', 'Manama', 'Bahrain', 26.2285, 50.5860),
    PrayerCity('om-muscat', 'Muscat', 'Oman', 23.5880, 58.3829),
    PrayerCity('om-salalah', 'Salalah', 'Oman', 17.0151, 54.0924),

    // ── Wider Asia ──────────────────────────────────────────────────────────
    PrayerCity('pk-karachi', 'Karachi', 'Pakistan', 24.8607, 67.0011),
    PrayerCity('pk-lahore', 'Lahore', 'Pakistan', 31.5204, 74.3587),
    PrayerCity('pk-islamabad', 'Islamabad', 'Pakistan', 33.6844, 73.0479),
    PrayerCity('bd-dhaka', 'Dhaka', 'Bangladesh', 23.8103, 90.4125),
    PrayerCity('bd-chattogram', 'Chattogram', 'Bangladesh', 22.3569, 91.7832),
    PrayerCity('lk-colombo', 'Colombo', 'Sri Lanka', 6.9271, 79.8612),
    PrayerCity('mv-male', 'Male', 'Maldives', 4.1755, 73.5093),
    PrayerCity('np-kathmandu', 'Kathmandu', 'Nepal', 27.7172, 85.3240),
    PrayerCity('my-kl', 'Kuala Lumpur', 'Malaysia', 3.1390, 101.6869),
    PrayerCity('sg-singapore', 'Singapore', 'Singapore', 1.3521, 103.8198),
    PrayerCity('id-jakarta', 'Jakarta', 'Indonesia', -6.2088, 106.8456),
    PrayerCity('th-bangkok', 'Bangkok', 'Thailand', 13.7563, 100.5018),
    PrayerCity('tr-istanbul', 'Istanbul', 'Turkiye', 41.0082, 28.9784),
    PrayerCity('tr-ankara', 'Ankara', 'Turkiye', 39.9334, 32.8597),
    PrayerCity('eg-cairo', 'Cairo', 'Egypt', 30.0444, 31.2357),
    PrayerCity('jo-amman', 'Amman', 'Jordan', 31.9454, 35.9284),
    PrayerCity('iq-baghdad', 'Baghdad', 'Iraq', 33.3152, 44.3661),
    PrayerCity('ir-tehran', 'Tehran', 'Iran', 35.6892, 51.3890),

    // ── Europe, Americas, Oceania, Africa ───────────────────────────────────
    PrayerCity('gb-london', 'London', 'United Kingdom', 51.5074, -0.1278),
    PrayerCity('gb-manchester', 'Manchester', 'United Kingdom', 53.4808, -2.2426),
    PrayerCity('gb-birmingham', 'Birmingham', 'United Kingdom', 52.4862, -1.8904),
    PrayerCity('fr-paris', 'Paris', 'France', 48.8566, 2.3522),
    PrayerCity('de-berlin', 'Berlin', 'Germany', 52.5200, 13.4050),
    PrayerCity('de-frankfurt', 'Frankfurt', 'Germany', 50.1109, 8.6821),
    PrayerCity('nl-amsterdam', 'Amsterdam', 'Netherlands', 52.3676, 4.9041),
    PrayerCity('se-stockholm', 'Stockholm', 'Sweden', 59.3293, 18.0686),
    PrayerCity('no-oslo', 'Oslo', 'Norway', 59.9139, 10.7522),
    PrayerCity('ru-moscow', 'Moscow', 'Russia', 55.7558, 37.6173),
    PrayerCity('us-newyork', 'New York', 'United States', 40.7128, -74.0060),
    PrayerCity('us-chicago', 'Chicago', 'United States', 41.8781, -87.6298),
    PrayerCity('us-houston', 'Houston', 'United States', 29.7604, -95.3698),
    PrayerCity('us-la', 'Los Angeles', 'United States', 34.0522, -118.2437),
    PrayerCity('ca-toronto', 'Toronto', 'Canada', 43.6532, -79.3832),
    PrayerCity('ca-vancouver', 'Vancouver', 'Canada', 49.2827, -123.1207),
    PrayerCity('au-sydney', 'Sydney', 'Australia', -33.8688, 151.2093),
    PrayerCity('au-melbourne', 'Melbourne', 'Australia', -37.8136, 144.9631),
    PrayerCity('za-johannesburg', 'Johannesburg', 'South Africa', -26.2041, 28.0473),
    PrayerCity('ke-nairobi', 'Nairobi', 'Kenya', -1.2921, 36.8219),
    PrayerCity('ng-lagos', 'Lagos', 'Nigeria', 6.5244, 3.3792),
  ];

  static PrayerCity? byId(String? id) {
    if (id == null) return null;
    for (final c in all) {
      if (c.id == id) return c;
    }
    return null;
  }

  /// Case-insensitive match on city or region, ordered so that a name hit
  /// outranks a region hit and a prefix outranks a mid-string match.
  static List<PrayerCity> search(String query) {
    final q = query.trim().toLowerCase();
    if (q.isEmpty) return all;
    final scored = <({PrayerCity city, int rank})>[];
    for (final c in all) {
      final name = c.name.toLowerCase();
      final region = c.region.toLowerCase();
      int? rank;
      if (name.startsWith(q)) {
        rank = 0;
      } else if (name.contains(q)) {
        rank = 1;
      } else if (region.startsWith(q)) {
        rank = 2;
      } else if (region.contains(q)) {
        rank = 3;
      }
      if (rank != null) scored.add((city: c, rank: rank));
    }
    scored.sort((a, b) => a.rank != b.rank
        ? a.rank.compareTo(b.rank)
        : a.city.name.compareTo(b.city.name));
    return [for (final s in scored) s.city];
  }

  /// Nearest bundled city to a fix, used only to label a GPS result. An
  /// equirectangular approximation is enough when the answer is a display name
  /// — the stored coordinates stay exact.
  static PrayerCity nearest(double lat, double lng) {
    var best = all.first;
    var bestD = double.infinity;
    for (final c in all) {
      final dLat = c.lat - lat;
      final dLng = (c.lng - lng) * 0.7; // rough cos(latitude) flattening
      final d = dLat * dLat + dLng * dLng;
      if (d < bestD) {
        bestD = d;
        best = c;
      }
    }
    return best;
  }
}
