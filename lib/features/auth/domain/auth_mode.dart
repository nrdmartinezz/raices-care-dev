/// Which half of the auth card is showing.
///
/// All the copy that differs between the two lives here, so the screen reads
/// as one layout with swapped strings rather than two near-identical trees.
enum AuthMode {
  signIn(
    eyebrow: 'ACCOUNT LOGIN',
    title: 'Sign in to your account',
    submitLabel: 'Sign In',
    footerPrompt: "Don't have an account?",
    footerAction: 'Sign up',
  ),
  signUp(
    eyebrow: 'CREATE ACCOUNT',
    title: 'Start your garden',
    submitLabel: 'Create Account',
    footerPrompt: 'Already have an account?',
    footerAction: 'Sign in',
  );

  const AuthMode({
    required this.eyebrow,
    required this.title,
    required this.submitLabel,
    required this.footerPrompt,
    required this.footerAction,
  });

  final String eyebrow;
  final String title;
  final String submitLabel;
  final String footerPrompt;
  final String footerAction;

  bool get isSignUp => this == AuthMode.signUp;

  AuthMode get opposite => isSignUp ? AuthMode.signIn : AuthMode.signUp;
}
