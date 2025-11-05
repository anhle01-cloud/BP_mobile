import typography from '@tailwindcss/typography';

/** @type {import('tailwindcss').Config} */
export default {
	content: ['./src/**/*.{html,js,svelte,ts,md,svx}'],
	theme: {
		extend: {
			fontFamily: {
				sans: ['Bricolage Grotesque Variable', 'sans-serif'],
				mono: ['Maple Mono', 'monospace']
			},
			colors: {
				// BP Mobile Flutter app colors
				main: {
					DEFAULT: '#ff3f00',
					50: '#fff5f2',
					100: '#ffe6e0',
					200: '#ffccb3',
					300: '#ffa880',
					400: '#ff7d4d',
					500: '#ff3f00',
					600: '#ff2e00',
					700: '#cc2500',
					800: '#991c00',
					900: '#661300'
				},
				accent: {
					DEFAULT: '#1d4ed8',
					50: '#eef2ff',
					100: '#e0e7ff',
					200: '#c7d2fe',
					300: '#a5b4fc',
					400: '#818cf8',
					500: '#1d4ed8',
					600: '#1e40af',
					700: '#1e3a8a',
					800: '#1e293b',
					900: '#0f172a'
				},
				// Text colors from Flutter app
				text: {
					primary: '#000000',
					secondary: '#6b7280',
					tertiary: '#9ca3af'
				},
				// Background colors from Flutter app
				bg: {
					DEFAULT: '#ffffff',
					surface: '#f9fafb'
				},
				// Keep primary and accent as aliases for backward compatibility
				primary: {
					DEFAULT: '#ff3f00',
					50: '#fff5f2',
					100: '#ffe6e0',
					200: '#ffccb3',
					300: '#ffa880',
					400: '#ff7d4d',
					500: '#ff3f00',
					600: '#ff2e00',
					700: '#cc2500',
					800: '#991c00',
					900: '#661300'
				}
			}
		}
	},
	plugins: [typography]
};
