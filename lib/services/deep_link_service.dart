class DeepLinkTarget { final String type,idOrUsername; const DeepLinkTarget(this.type,this.idOrUsername); }
class DeepLinkService {
  static DeepLinkTarget? parse(String raw) {
    final uri=Uri.tryParse(raw); if(uri==null) return null; final p=uri.pathSegments.where((x)=>x.isNotEmpty).toList(); if(p.isEmpty) return null;
    if(p.first.startsWith('@')) return DeepLinkTarget('profile',p.first.substring(1).toLowerCase());
    const types={'player','club','scout','coach','post','reel','story','group','invite','message'};
    if(types.contains(p.first)&&p.length>=2) return DeepLinkTarget(p.first,p[1]);
    return null;
  }
  static String profile(String username)=>'/@${username.replaceFirst('@','').toLowerCase()}';
  static String object(String type,String id)=>'/$type/$id';
}
