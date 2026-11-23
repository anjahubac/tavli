/// Local rollout guards for persisting catalog links in recipe rows.
///
/// Both conditions must be explicitly enabled after every syncing device has
/// upgraded and its old outbox has drained. The shipped default stays closed.
final class RecipeLinkRollout {
  const RecipeLinkRollout({
    this.allDevicesAtCompatibleBuild = false,
    this.oldOutboxesDrained = false,
  });

  final bool allDevicesAtCompatibleBuild;
  final bool oldOutboxesDrained;

  bool get enabled => allDevicesAtCompatibleBuild && oldOutboxesDrained;
}

const recipeLinkRollout = RecipeLinkRollout();
