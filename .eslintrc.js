module.exports = {
  env: {
    node: true,
    mocha: true,
  },
  root: true,
  plugins: ['@typescript-eslint/eslint-plugin'],
  parser: '@typescript-eslint/parser',
  parserOptions: {
    project: './tsconfig.json',
    sourceType: 'module',
  },
  extends: [
    'plugin:@typescript-eslint/recommended',
    'plugin:prettier/recommended',
  ],
  ignorePatterns: ['**/*.js', 'dist', '**/*.d.ts'],
};
