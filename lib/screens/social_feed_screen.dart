import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../constants/app_colors.dart';
import '../models/social_models.dart';
import '../providers/social_provider.dart';
import '../providers/nav_provider.dart';
import '../services/supabase_service.dart';
import '../theme/app_theme.dart';
import 'package:share_plus/share_plus.dart';
import 'notifications_screen.dart';
import 'upload_screen.dart';

class SocialFeedScreen extends StatefulWidget {
  const SocialFeedScreen({super.key});
  @override
  State<SocialFeedScreen> createState() => _SocialFeedScreenState();
}

class _SocialFeedScreenState extends State<SocialFeedScreen> {
  final Set<String> _seenStories = <String>{};
  Map<String, Map<String, dynamic>> _profiles = <String, Map<String, dynamic>>{};
  Map<String, Map<String, dynamic>> _suggestions = <String, Map<String, dynamic>>{};
  String? _suggestedId;
  bool _suggestedFollowing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final social = context.read<SocialProvider>();
      await social.load();
      await _loadPeople(social);
      social.realtime();
    });
  }

  Future<void> _loadPeople(SocialProvider social) async {
    if (!SupabaseService.isReady || !mounted) return;
    try {
      final client = SupabaseService.client;
      final ids = social.posts.map((post) => post.authorId).toSet().toList();
      final storyIds = social.stories.map((story) => story.authorId).toSet().toList();
      final allIds = <String>{...ids, ...storyIds};
      final currentId = client.auth.currentUser?.id;
      if (allIds.isNotEmpty) {
        final rows = await client.from('profiles').select('user_id,username,display_name,avatar_url,verified').inFilter('user_id', allIds.toList());
        _profiles = {for (final row in rows) row['user_id'] as String: Map<String, dynamic>.from(row)};
      }
      if (currentId != null) {
        final follows = await client.from('profile_follows').select('followed_id').eq('follower_id', currentId);
        final followed = follows.map((row) => row['followed_id'] as String).toSet();
        final candidates = await client.from('profiles').select('user_id,username,display_name,avatar_url').neq('user_id', currentId).limit(30);
        final available = candidates.where((row) => !followed.contains(row['user_id'])).toList();
        if (available.isNotEmpty) {
          final selected = Map<String, dynamic>.from(available.first);
          _suggestedId = selected['user_id'] as String;
          _suggestions[_suggestedId!] = selected;
        }
      }
    } catch (_) {
      // Keep the feed usable when optional profile suggestions are unavailable.
    } finally {
      if (mounted) setState(() {});
    }
  }

  Future<void> _followSuggested() async {
    final id = _suggestedId;
    final me = SupabaseService.isReady ? SupabaseService.client.auth.currentUser?.id : null;
    if (id == null || me == null) return;
    try {
      await SupabaseService.client.from('profile_follows').insert({'follower_id': me, 'followed_id': id});
      if (mounted) setState(() => _suggestedFollowing = true);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not follow account: $error')));
    }
  }

  Future<void> _storyDialog() async {
    final url = TextEditingController();
    final caption = TextEditingController();
    String visibility = 'followers';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create story'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          TextField(controller: url, decoration: const InputDecoration(labelText: 'Image or video URL')),
          TextField(controller: caption, decoration: const InputDecoration(labelText: 'Caption')),
          DropdownButtonFormField<String>(
            value: visibility,
            decoration: const InputDecoration(labelText: 'Audience'),
            items: const [
              DropdownMenuItem(value: 'public', child: Text('Public')),
              DropdownMenuItem(value: 'followers', child: Text('Followers')),
              DropdownMenuItem(value: 'close_friends', child: Text('Close Friends')),
            ],
            onChanged: (value) { if (value != null) visibility = value; },
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Share')),
        ],
      ),
    );
    if (ok == true && url.text.trim().isNotEmpty && mounted) {
      await context.read<SocialProvider>().createStory(url.text.trim(), caption.text.trim(), visibility: visibility);
      await _loadPeople(context.read<SocialProvider>());
    }
    url.dispose();
    caption.dispose();
  }

  Future<void> _openStory(SocialStory story) async {
    try {
      await context.read<SocialProvider>().repository.viewStory(story.id);
      if (!mounted) return;
      setState(() => _seenStories.add(story.id));
      final profile = _profiles[story.authorId] ?? <String, dynamic>{};
      showDialog<void>(
        context: context,
        barrierColor: Colors.black,
        builder: (ctx) => Dialog.fullscreen(
          backgroundColor: Colors.black,
          child: Stack(children: [
            Center(child: story.mediaType == 'image'
                ? InteractiveViewer(child: Image.network(story.mediaUrl, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image_outlined, color: Colors.white)))
                : const Center(child: Text('This story media format cannot be previewed here.', style: TextStyle(color: Colors.white)))),
            SafeArea(child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(children: [
                _Avatar(url: profile['avatar_url'] as String?, name: profile['display_name'] as String?),
                const SizedBox(width: 10),
                Expanded(child: Text(profile['username'] as String? ?? 'FUSKAMO member', style: AppTheme.body(14, weight: FontWeight.w600))),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Colors.white)),
              ]),
            )),
            if (story.caption.isNotEmpty) Positioned(left: 18, right: 18, bottom: 36, child: Text(story.caption, style: AppTheme.body(15))),
          ]),
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Story could not be opened: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocialProvider>(builder: (context, social, _) {
      final stories = [...social.stories]..sort((a, b) {
        final aSeen = _seenStories.contains(a.id);
        final bSeen = _seenStories.contains(b.id);
        if (aSeen != bSeen) return aSeen ? 1 : -1;
        return b.createdAt.compareTo(a.createdAt);
      });
      return ColoredBox(
        color: AppColors.black,
        child: Column(children: [
          _header(),
          SizedBox(
            height: 112,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              itemCount: stories.length + 1,
              separatorBuilder: (_, __) => const SizedBox(width: 12),
              itemBuilder: (_, index) => index == 0
                  ? _StoryBubble(label: 'Your story', imageUrl: SupabaseService.isReady ? null : null, own: true, onTap: _storyDialog)
                  : _StoryBubble(
                      label: _profiles[stories[index - 1].authorId]?['username'] as String? ?? 'Member',
                      imageUrl: _profiles[stories[index - 1].authorId]?['avatar_url'] as String?,
                      seen: _seenStories.contains(stories[index - 1].id),
                      onTap: () => _openStory(stories[index - 1]),
                    ),
            ),
          ),
          if (_suggestedId != null && _suggestions[_suggestedId!] != null)
            _suggestedAccount(_suggestions[_suggestedId!]!),
          Expanded(
            child: social.loading && social.posts.isEmpty
                ? const Center(child: CircularProgressIndicator(color: AppColors.text))
                : social.error != null && social.posts.isEmpty
                    ? _messageState('Could not load your feed', 'Check your connection and try again.', onRetry: social.load)
                    : social.posts.isEmpty
                        ? _messageState('Your feed starts here', 'Follow footballers, scouts and clubs to see their posts.')
                        : RefreshIndicator(
                            color: AppColors.text,
                            backgroundColor: AppColors.surface,
                            onRefresh: () async { await social.load(); await _loadPeople(social); },
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              itemCount: social.posts.length,
                              itemBuilder: (_, index) => _PostCard(
                                post: social.posts[index],
                                profile: _profiles[social.posts[index].authorId],
                              ),
                            ),
                          ),
          ),
        ]),
      );
    });
  }

  Future<void> _openCreateMenu() async {
    final choice = await showModalBottomSheet<String>(context: context, backgroundColor: AppColors.surface, builder: (sheetContext) => SafeArea(child: Column(mainAxisSize: MainAxisSize.min, children: [
      ListTile(leading: const Icon(Icons.add_circle_outline), title: const Text('Story'), subtitle: const Text('Share a moment for 24 hours'), onTap: () => Navigator.pop(sheetContext, 'story')),
      ListTile(leading: const Icon(Icons.photo_camera_outlined), title: const Text('Post'), subtitle: const Text('Share a photo, video or update'), onTap: () => Navigator.pop(sheetContext, 'post')),
      ListTile(leading: const Icon(Icons.play_circle_outline), title: const Text('Reel'), subtitle: const Text('Create a short football video'), onTap: () => Navigator.pop(sheetContext, 'reel')),
      ListTile(leading: const Icon(Icons.person_add_alt_1), title: const Text('Submit player'), subtitle: const Text('Add a player profile for review'), onTap: () => Navigator.pop(sheetContext, 'player')),
    ])));
    if (!mounted || choice == null) return;
    if (choice == 'story') await _storyDialog();
    if (choice == 'reel') context.read<NavProvider>().setIndex(1);
    if (choice == 'player') await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const UploadScreen()));
    if (choice == 'post') await _postDialog();
  }

  Future<void> _postDialog() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(context: context, builder: (dialogContext) => AlertDialog(
      title: const Text('Create post'),
      content: TextField(controller: controller, minLines: 3, maxLines: 6, maxLength: 2200, decoration: const InputDecoration(hintText: 'Share a football moment…')),
      actions: [TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(dialogContext, true), child: const Text('Share'))],
    ));
    final body = controller.text.trim();
    controller.dispose();
    if (ok == true && body.isNotEmpty && mounted) await context.read<SocialProvider>().createPost(body);
  }

  Widget _header() => SizedBox(
    height: 54,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(children: [
        IconButton(onPressed: _openCreateMenu, icon: const Icon(Icons.add, size: 29, color: AppColors.text), tooltip: 'Create'),
        const Spacer(),
        Text('FUSKAMO', style: AppTheme.display(27, color: AppColors.text)),
        const Spacer(),
        IconButton(onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen())), icon: const Icon(Icons.favorite_border, size: 27, color: AppColors.text), tooltip: 'Activity'),
      ]),
    ),
  );

  Widget _suggestedAccount(Map<String, dynamic> profile) => Container(
    height: 66,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border))),
    child: Row(children: [
      _Avatar(url: profile['avatar_url'] as String?, name: profile['display_name'] as String?),
      const SizedBox(width: 10),
      Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(profile['username'] as String? ?? profile['display_name'] as String? ?? 'FUSKAMO member', maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(14, weight: FontWeight.w700)),
        Text('Suggested for you', style: AppTheme.body(12, color: AppColors.sub)),
      ])),
      OutlinedButton(
        onPressed: _suggestedFollowing ? null : _followSuggested,
        style: OutlinedButton.styleFrom(foregroundColor: AppColors.text, side: const BorderSide(color: AppColors.sub), padding: const EdgeInsets.symmetric(horizontal: 18), minimumSize: const Size(0, 36)),
        child: Text(_suggestedFollowing ? 'Following' : 'Follow'),
      ),
    ]),
  );

  Widget _messageState(String title, String description, {Future<void> Function()? onRetry}) => Center(
    child: Padding(padding: const EdgeInsets.all(28), child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(title, style: AppTheme.body(17, weight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text(description, textAlign: TextAlign.center, style: AppTheme.body(13, color: AppColors.sub)),
      if (onRetry != null) TextButton(onPressed: onRetry, child: const Text('Try again')),
    ])),
  );
}

class _Avatar extends StatelessWidget {
  final String? url;
  final String? name;
  const _Avatar({this.url, this.name});
  @override
  Widget build(BuildContext context) => CircleAvatar(
    radius: 18,
    backgroundColor: AppColors.surface,
    backgroundImage: url == null || url!.isEmpty ? null : NetworkImage(url!),
    child: url == null || url!.isEmpty ? Text((name?.isNotEmpty == true ? name![0] : 'F').toUpperCase(), style: AppTheme.body(12, weight: FontWeight.w700)) : null,
  );
}

class _StoryBubble extends StatelessWidget {
  final String label;
  final String? imageUrl;
  final bool own;
  final bool seen;
  final VoidCallback onTap;
  const _StoryBubble({required this.label, this.imageUrl, this.own = false, this.seen = false, required this.onTap});
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: SizedBox(width: 78, child: Column(children: [
      Stack(clipBehavior: Clip.none, children: [
        Container(
          width: 72, height: 72, padding: const EdgeInsets.all(3),
          decoration: BoxDecoration(shape: BoxShape.circle, gradient: seen ? null : const SweepGradient(colors: [Color(0xFFFEDA75), Color(0xFFFA7E1E), Color(0xFFD62976), Color(0xFF962FBF), Color(0xFFFEDA75)]), color: seen ? AppColors.muted : null),
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.black),
            child: CircleAvatar(backgroundColor: AppColors.surface, backgroundImage: imageUrl == null || imageUrl!.isEmpty ? null : NetworkImage(imageUrl!), child: imageUrl == null || imageUrl!.isEmpty ? const Icon(Icons.person_outline, color: AppColors.sub) : null),
          ),
        ),
        if (own) const Positioned(right: 0, bottom: 0, child: CircleAvatar(radius: 11, backgroundColor: AppColors.text, child: Icon(Icons.add, color: AppColors.black, size: 17))),
      ]),
      const SizedBox(height: 4),
      Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(11, color: AppColors.text)),
    ])),
  );
}

class _PostCard extends StatefulWidget {
  final SocialPost post;
  final Map<String, dynamic>? profile;
  const _PostCard({required this.post, this.profile});
  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  bool _liked = false;
  bool _saved = false;
  bool _busy = false;

  Future<void> _like() async {
    if (_busy) return;
    setState(() { _liked = !_liked; _busy = true; });
    try {
      await context.read<SocialProvider>().toggleLike(widget.post.id);
    } catch (error) {
      if (mounted) setState(() => _liked = !_liked);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not update like: $error')));
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _showComments() async {
    final repository = context.read<SocialProvider>().repository;
    final controller = TextEditingController();
    try {
      final comments = await repository.comments(widget.post.id);
      if (!mounted) return;
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: AppColors.surface,
        builder: (sheetContext) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(sheetContext).viewInsets.bottom),
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * .72,
            child: Column(children: [
              Padding(padding: const EdgeInsets.all(16), child: Text('Comments', style: AppTheme.display(22))),
              Expanded(child: ListView(children: comments.map((comment) => ListTile(title: Text(comment.body), subtitle: const Text('FUSKAMO member'))).toList())),
              Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                Expanded(child: TextField(controller: controller, decoration: const InputDecoration(hintText: 'Add a comment…'))),
                IconButton(onPressed: () async {
                  final body = controller.text.trim();
                  if (body.isEmpty) return;
                  try {
                    await repository.addComment(widget.post.id, body);
                    controller.clear();
                    if (sheetContext.mounted) Navigator.pop(sheetContext);
                  } catch (error) {
                    if (sheetContext.mounted) ScaffoldMessenger.of(sheetContext).showSnackBar(SnackBar(content: Text('Could not add comment: $error')));
                  }
                }, icon: const Icon(Icons.send, color: AppColors.text)),
              ])),
            ]),
          ),
        ),
      );
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not load comments: $error')));
    } finally {
      controller.dispose();
    }
  }
  Future<void> _save() async {
    try {
      final saved = await context.read<SocialProvider>().savePost(widget.post.id);
      if (mounted) setState(() => _saved = saved);
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not save post: $error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final name = widget.profile?['username'] as String? ?? widget.profile?['display_name'] as String? ?? 'FUSKAMO member';
    final media = post.mediaUrl;
    return Container(
      color: AppColors.black,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 12, 9),
          child: Row(children: [
            _Avatar(url: widget.profile?['avatar_url'] as String?, name: name),
            const SizedBox(width: 10),
            Expanded(child: Text(name, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTheme.body(14, weight: FontWeight.w700))),
            Text(_age(post.createdAt), style: AppTheme.body(11, color: AppColors.sub)),
            PopupMenuButton<String>(onSelected: (value) async {
              if (value == 'report') await context.read<SocialProvider>().repository.report(targetType: 'post', targetId: post.id, reason: 'other');
            }, itemBuilder: (_) => const [PopupMenuItem(value: 'report', child: Text('Report'))], iconColor: AppColors.text),
          ]),
        ),
        if (media != null && media.isNotEmpty)
          Container(
            width: double.infinity,
            color: Colors.black,
            constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * .72),
            child: post.mediaType == 'image'
                ? Image.network(media, fit: BoxFit.contain, errorBuilder: (_, __, ___) => const SizedBox(height: 180, child: Center(child: Icon(Icons.broken_image_outlined, color: AppColors.sub))))
                : const SizedBox(height: 180, child: Center(child: Icon(Icons.play_circle_outline, size: 42, color: AppColors.text))),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
          child: Row(children: [
            IconButton(onPressed: _like, icon: Icon(_liked ? Icons.favorite : Icons.favorite_border, color: _liked ? AppColors.red : AppColors.text, size: 26)),
            Text('${post.likeCount + (_liked ? 1 : 0)}', style: AppTheme.body(12)),
            IconButton(onPressed: _showComments, icon: const Icon(Icons.mode_comment_outlined, color: AppColors.text, size: 25)),
            Text('${post.commentCount}', style: AppTheme.body(12)),
            IconButton(onPressed: () => Share.share('FUSKAMO: ${post.body}'), icon: const Icon(Icons.send_outlined, color: AppColors.text, size: 25)),
            const Spacer(),
            IconButton(onPressed: _save, icon: Icon(_saved ? Icons.bookmark : Icons.bookmark_border, color: AppColors.text, size: 25)),
          ]),
        ),
        if (post.body.isNotEmpty) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: RichText(text: TextSpan(style: AppTheme.body(13), children: [
            TextSpan(text: '$name ', style: AppTheme.body(13, weight: FontWeight.w700)),
            TextSpan(text: post.body),
          ])),
        ),
      ]),
    );
  }

  String _age(DateTime date) {
    final minutes = DateTime.now().difference(date).inMinutes;
    if (minutes < 60) return '${minutes}m';
    if (minutes < 1440) return '${minutes ~/ 60}h';
    return '${minutes ~/ 1440}d';
  }
}
