<script lang="ts">
	import { page } from '$app/stores';
	import '../app.css';

	const docs = [
		{ id: 'getting-started', title: 'Getting Started', path: '/docs/getting-started' },
		{ id: 'connection', title: 'ESP32 Connection Guide', path: '/docs/connection' },
		{ id: 'protocol', title: 'WebSocket Protocol', path: '/docs/protocol' },
		{ id: 'examples', title: 'Code Examples', path: '/docs/examples' }
	];

	$: currentPath = $page.url.pathname;
</script>

<svelte:options tag="div" />

<div class="container mx-auto max-w-6xl px-8 py-12">
	<header class="mb-12 text-center border-b border-gray-200 pb-8">
		<h1 class="text-5xl font-bold mb-3 text-text-primary">BP Mobile Documentation</h1>
		<p class="text-xl text-text-secondary">Complete guide for connecting ESP32 devices to the BP Mobile data logging app</p>
	</header>

	<nav class="flex flex-wrap gap-4 mb-12">
		{#each docs as doc}
			<a 
				href={doc.path} 
				class="px-6 py-3 rounded-lg font-medium transition-all {currentPath === doc.path ? 'bg-main text-white hover:bg-main-600' : 'bg-bg-surface text-text-secondary hover:bg-gray-200'}"
			>
				{doc.title}
			</a>
		{/each}
	</nav>

	<main class="prose prose-lg max-w-none prose-headings:text-text-primary prose-headings:font-bold prose-p:text-text-primary prose-p:leading-relaxed prose-a:text-accent prose-a:font-semibold prose-a:no-underline hover:prose-a:underline prose-code:font-mono prose-code:text-red-600 prose-code:bg-bg-surface prose-code:px-1.5 prose-code:py-0.5 prose-code:rounded prose-pre:bg-gray-900 prose-pre:text-gray-100 prose-pre:overflow-x-auto prose-strong:text-text-primary prose-ul:text-text-primary prose-ol:text-text-primary prose-li:text-text-primary">
		<slot />
	</main>
</div>
