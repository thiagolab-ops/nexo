module.exports = {
  root: true,
  env: {
    es6: true,
    node: true,
  },
  extends: [
    "eslint:recommended",
    "google",
  ],
  parserOptions: {
    "ecmaVersion": 2020,
  },
  rules: {
    "quotes": ["error", "double"],
    "max-len": "off", // <-- AQUI ESTÁ A MÁGICA: DESLIGA A REGRA
  },
};
