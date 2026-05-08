import type { Config } from 'tailwindcss';

export default {
  content: ['./index.html', './src/**/*.{ts,tsx}'],
  theme: {
    extend: {
      colors: {
        ink: '#13212c',
        paper: '#f8f1e5',
        ember: '#d45b38',
        moss: '#6a7b54',
        steel: '#5f7a86',
        sun: '#f2c14e',
      },
      boxShadow: {
        soft: '0 20px 50px rgba(19, 33, 44, 0.12)',
      },
      fontFamily: {
        display: ['"Iowan Old Style"', '"Palatino Linotype"', 'Georgia', 'serif'],
        body: ['"IBM Plex Sans"', '"Trebuchet MS"', 'sans-serif'],
      },
    },
  },
  plugins: [],
} satisfies Config;
