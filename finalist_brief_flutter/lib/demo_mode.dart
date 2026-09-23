/// Enables replay in the retained, opt-in `?legacy=1&demo=1` video flow.
/// The current visual exploration uses cached data at both `/` and `?demo=1`.
bool get isDemoMode => Uri.base.queryParameters['demo'] == '1';
