import adapter from '@sveltejs/adapter-static';
import { vitePreprocess } from '@sveltejs/vite-plugin-svelte';
import { mdsvex } from 'mdsvex';

/** @type {import('@sveltejs/kit').Config} */
const config = {
	extensions: ['.svelte', '.md', '.svx'],
	preprocess: [
		mdsvex({
			remarkPlugins: [],
			rehypePlugins: [],
			layout: false,
			smartypants: false
		}),
		vitePreprocess({
			// Disable Svelte script parsing for markdown files
			script: false
		})
	],

	kit: {
		adapter: adapter({
			pages: 'build',
			assets: 'build',
			fallback: undefined,
			precompress: false,
			strict: true
		}),
		paths: {
			base: process.env.NODE_ENV === 'production' ? '/BP_mobile/docs' : ''
		},
		prerender: {
			handleHttpError: 'warn'
		}
	}
};

export default config;
