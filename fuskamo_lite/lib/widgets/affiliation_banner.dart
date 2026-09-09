import 'package:flutter/material.dart';
import '../constants/app_colors.dart';
import '../theme/app_theme.dart';

class AffiliationBanner extends StatelessWidget {
  final String? notice;
  const AffiliationBanner({super.key,this.notice});
  @override Widget build(BuildContext context){
    if(notice==null||notice!.trim().isEmpty)return const SizedBox.shrink();
    return Container(margin:const EdgeInsets.only(top:10),padding:const EdgeInsets.all(12),decoration:BoxDecoration(color:AppColors.card,borderRadius:BorderRadius.circular(10),border:Border.all(color:AppColors.amber)),child:Row(crossAxisAlignment:CrossAxisAlignment.start,children:[const Icon(Icons.info_outline,color:AppColors.amber,size:18),const SizedBox(width:8),Expanded(child:Text(notice!,style:AppTheme.body(11,color:AppColors.sub)))]));
  }
}
