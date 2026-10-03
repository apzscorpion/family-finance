import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/user_model.dart';
import '../models/organization_model.dart';
import '../models/transaction_model.dart';

class ApiService {
  final String baseUrl;
  String? authToken;

  ApiService({this.baseUrl = 'http://10.0.2.2:8000/api/v1'});

  Map<String, String> get _headers => {
    'Content-Type': 'application/json',
    if (authToken != null) 'Authorization': 'Bearer $authToken',
  };

  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/login'),
      headers: _headers,
      body: jsonEncode({'email': email, 'password': password}),
    );
    if (res.statusCode == 200) {
      final data = jsonDecode(res.body);
      authToken = data['access_token'];
      return data;
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Login failed');
  }

  Future<UserModel> register(String email, String password, String fullName) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/register'),
      headers: _headers,
      body: jsonEncode({
        'email': email,
        'password': password,
        'full_name': fullName,
      }),
    );
    if (res.statusCode == 201) {
      return UserModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Registration failed');
  }

  Future<OrganizationModel> createOrganization(String name, String? description) async {
    final res = await http.post(
      Uri.parse('$baseUrl/organizations'),
      headers: _headers,
      body: jsonEncode({'name': name, 'description': description}),
    );
    if (res.statusCode == 201) {
      return OrganizationModel.fromJson(jsonDecode(res.body));
    }
    throw Exception(jsonDecode(res.body)['detail'] ?? 'Failed to create organization');
  }

  Future<List<MemberModel>> getMembers(String orgId) async {
    final res = await http.get(
      Uri.parse('$baseUrl/organizations/$orgId/members'),
      headers: _headers,
    );
    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((m) => MemberModel.fromJson(m)).toList();
    }
    throw Exception('Failed to load members');
  }

  Future<List<TransactionModel>> getTransactions({
    String? targetUserId,
    String? orgId,
    String? category,
  }) async {
    final params = <String, String>{};
    if (targetUserId != null) params['target_user_id'] = targetUserId;
    if (orgId != null) params['org_id'] = orgId;
    if (category != null) params['category'] = category;

    final uri = Uri.parse('$baseUrl/transactions').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);

    if (res.statusCode == 200) {
      final List list = jsonDecode(res.body);
      return list.map((t) => TransactionModel.fromJson(t)).toList();
    }
    throw Exception('Failed to fetch transactions');
  }

  Future<Map<String, dynamic>> getPersonalDashboard() async {
    final res = await http.get(Uri.parse('$baseUrl/dashboards/personal'), headers: _headers);
    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load personal dashboard');
  }

  Future<Map<String, dynamic>> getOrganizationDashboard(String orgId, {String? targetMemberId}) async {
    final params = <String, String>{};
    if (targetMemberId != null) params['target_member_user_id'] = targetMemberId;

    final uri = Uri.parse('$baseUrl/dashboards/organization/$orgId').replace(queryParameters: params);
    final res = await http.get(uri, headers: _headers);

    if (res.statusCode == 200) {
      return jsonDecode(res.body);
    }
    throw Exception('Failed to load organization dashboard');
  }
}
