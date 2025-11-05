<script lang="ts">
	import { goto } from '$app/navigation';
</script>

<svelte:head>
	<title>BP Mobile - ESP32 Documentation</title>
	<meta name="description" content="Documentation for connecting ESP32 devices to BP Mobile app" />
</svelte:head>

<div class="container mx-auto max-w-6xl px-8 py-12">
	<header class="mb-12 text-center border-b border-gray-200 pb-8">
		<h1 class="text-5xl font-bold mb-3 text-text-primary">BP Mobile Documentation</h1>
		<p class="text-xl text-text-secondary">Complete guide for connecting ESP32 devices to the BP Mobile data logging app</p>
	</header>

	<main class="space-y-6">
		<h2 class="text-3xl font-bold text-text-primary">Welcome</h2>
		<p class="text-lg text-text-primary leading-relaxed">
			This documentation will help you connect your ESP32 devices to the BP Mobile app using WebSocket communication.
		</p>
		<p class="text-lg text-text-primary leading-relaxed">
			Start with the <a href="/docs/getting-started" class="text-accent font-semibold hover:underline">Getting Started</a> guide.
		</p>
		
		<div class="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-6 mt-8">
			<a href="/docs/getting-started" class="group bg-bg border border-gray-200 rounded-lg p-6 transition-all hover:border-main hover:shadow-lg hover:-translate-y-1">
				<h3 class="text-xl font-semibold mb-2 text-text-primary">Getting Started</h3>
				<p class="text-sm text-text-secondary">Quick start guide for connecting your ESP32 to BP Mobile</p>
			</a>
			<a href="/docs/connection" class="group bg-bg border border-gray-200 rounded-lg p-6 transition-all hover:border-main hover:shadow-lg hover:-translate-y-1">
				<h3 class="text-xl font-semibold mb-2 text-text-primary">Connection Guide</h3>
				<p class="text-sm text-text-secondary">Step-by-step instructions for establishing the connection</p>
			</a>
			<a href="/docs/protocol" class="group bg-bg border border-gray-200 rounded-lg p-6 transition-all hover:border-main hover:shadow-lg hover:-translate-y-1">
				<h3 class="text-xl font-semibold mb-2 text-text-primary">WebSocket Protocol</h3>
				<p class="text-sm text-text-secondary">Complete reference for the WebSocket message protocol</p>
			</a>
			<a href="/docs/examples" class="group bg-bg border border-gray-200 rounded-lg p-6 transition-all hover:border-main hover:shadow-lg hover:-translate-y-1">
				<h3 class="text-xl font-semibold mb-2 text-text-primary">Code Examples</h3>
				<p class="text-sm text-text-secondary">Ready-to-use Arduino sketches and code samples</p>
			</a>
		</div>
	</main>
</div>
