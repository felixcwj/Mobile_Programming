/// Customer support recipient. Can be overridden for another environment.
const defaultSupportEmail = String.fromEnvironment(
  'SUPPORT_EMAIL',
  defaultValue: 'miinkoo0044@gmail.com',
);
