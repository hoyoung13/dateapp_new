import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'constants.dart';
import 'user_provider.dart';
import 'foodplace.dart';

class AdminPlaceRequestDetailPage extends StatefulWidget {
  final int placeId;
  const AdminPlaceRequestDetailPage({Key? key, required this.placeId})
      : super(key: key);

  @override
  State<AdminPlaceRequestDetailPage> createState() =>
      _AdminPlaceRequestDetailPageState();
}

class _AdminPlaceRequestDetailPageState
    extends State<AdminPlaceRequestDetailPage> {
  Map<String, dynamic>? _place;
  int? _adminId;

  @override
  void initState() {
    super.initState();
    _adminId = Provider.of<UserProvider>(context, listen: false).userId ?? 8;
    _load();
  }

  Future<Map<String, String>> _authHeaders() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('token');
    final headers = {
      'Content-Type': 'application/json',
      'user_id': '$_adminId',
    };
    if (token != null) headers['Authorization'] = 'Bearer $token';
    return headers;
  }

  Future<void> _load() async {
    final uri = Uri.parse('${BASE_URL}/admin/places/${widget.placeId}');
    final headers = await _authHeaders();
    final resp = await http.get(uri, headers: headers);
    if (resp.statusCode == 200) {
      setState(() {
        _place = jsonDecode(resp.body) as Map<String, dynamic>;
      });
    }
  }

  Future<void> _approve() async {
    final uri =
        Uri.parse('${BASE_URL}/admin/place-requests/${widget.placeId}/approve');
    final headers = await _authHeaders();
    await http.post(uri, headers: headers);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  Future<void> _reject() async {
    final uri =
        Uri.parse('${BASE_URL}/admin/place-requests/${widget.placeId}/reject');
    final headers = await _authHeaders();
    await http.post(uri, headers: headers);
    if (!mounted) return;
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    if (_place == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return PlaceInPageUIOnly(
      payload: _place!,
      onApprove: _approve,
      onDelete: _reject,
    );
  }
}
