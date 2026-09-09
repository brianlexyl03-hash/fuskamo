import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'platform_operations_service.dart';
class OfflineOperation { final String id,type; final String? targetType,targetId; final Map<String,dynamic> payload; final DateTime createdAt; OfflineOperation({required this.id,required this.type,this.targetType,this.targetId,required this.payload,required this.createdAt}); Map<String,dynamic> toJson()=>{'id':id,'type':type,'targetType':targetType,'targetId':targetId,'payload':payload,'createdAt':createdAt.toIso8601String()}; factory OfflineOperation.fromJson(Map<String,dynamic> j)=>OfflineOperation(id:j['id'],type:j['type'],targetType:j['targetType'],targetId:j['targetId'],payload:Map<String,dynamic>.from(j['payload']??{}),createdAt:DateTime.parse(j['createdAt'])); }
class OfflineSyncService {
  static const _key='fuskamo_offline_outbox_v1'; final _api=PlatformOperationsService();
  Future<List<OfflineOperation>> _read() async { final p=await SharedPreferences.getInstance(); final raw=p.getString(_key); if(raw==null)return []; final l=jsonDecode(raw) as List; return l.map((e)=>OfflineOperation.fromJson(Map<String,dynamic>.from(e))).toList(); }
  Future<void> _write(List<OfflineOperation> ops) async { final p=await SharedPreferences.getInstance(); await p.setString(_key,jsonEncode(ops.map((e)=>e.toJson()).toList())); }
  Future<void> enqueue({required String id,required String type,String? targetType,String? targetId,Map<String,dynamic> payload=const {}}) async { final ops=await _read(); if(ops.any((e)=>e.id==id))return; ops.add(OfflineOperation(id:id,type:type,targetType:targetType,targetId:targetId,payload:payload,createdAt:DateTime.now())); await _write(ops); }
  Future<int> pendingCount() async=>(await _read()).length;
  Future<void> clear() async { await _write([]); }
  Future<void> flush() async { final ops=await _read(); if(ops.isEmpty)return; try { final applied=await _api.syncOperations(ops.map((o)=>{'clientOperationId':o.id,'operationType':o.type,'targetType':o.targetType,'targetId':o.targetId,'payload':o.payload}).toList()); final ids=applied.map((x)=>x.toString()).toSet(); await _write(ops.where((o)=>!ids.contains(o.id)).toList()); } catch (_) {} }
}
