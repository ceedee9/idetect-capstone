// Mirrors apps/api/src/utils/passwordPolicy.js and apps/web/src/utils/passwordPolicy.js. Keep all three in sync.

const int passwordMinLength = 8;
const int passwordMaxLength = 128;

class PasswordRule {
  const PasswordRule(this.label, this.test);

  final String label;
  final bool Function(String password) test;
}

final _uppercase = RegExp(r'[A-Z]');
final _lowercase = RegExp(r'[a-z]');
final _digit = RegExp(r'[0-9]');
// Anything that is not a letter, digit, or whitespace counts as special.
final _special = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);

final List<PasswordRule> passwordRules = [
  PasswordRule(
    'At least $passwordMinLength characters',
    (p) => p.length >= passwordMinLength,
  ),
  PasswordRule('One uppercase letter (A-Z)', _uppercase.hasMatch),
  PasswordRule('One lowercase letter (a-z)', _lowercase.hasMatch),
  PasswordRule('One number (0-9)', _digit.hasMatch),
  PasswordRule('One special character (e.g. ! @ # \$ %)', _special.hasMatch),
];

List<PasswordRule> failedPasswordRules(String password) =>
    passwordRules.where((rule) => !rule.test(password)).toList();

bool isPasswordValid(String password) => failedPasswordRules(password).isEmpty;
