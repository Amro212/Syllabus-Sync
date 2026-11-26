const contact = '<a href="mailto:syllabussync@itsamro.me">syllabussync@itsamro.me</a>';

const pages = {
	'/privacy': {
		title: 'Privacy Policy',
		content: `
			<p class="updated">Effective November 26, 2026</p>
			<p>This policy explains how Syllabus Sync handles information when you use the app or contact support.</p>
			<h2>Information you provide</h2>
			<p>When you create an account, we use your email address, account identifier, and sign-in information to authenticate you. We store your username, display name, courses, reminders, grading information, and preferences so you can use the app and sync your data across devices. If you use Google or Apple to sign in, we receive the account information that provider shares with us.</p>
			<h2>Syllabus scanning</h2>
			<p>When you choose an AI scan and give permission, Syllabus Sync extracts text from your PDF on your device. The app sends the extracted text to our Cloudflare Worker, which sends it to OpenAI to identify course details, deadlines, and grading information. Syllabus text can contain names, email addresses, and other personal information. Only scan documents you have permission to use. You can add reminders manually without using an AI scan.</p>
			<h2>Friends and schedule sharing</h2>
			<p>Other signed-in users can find your username and display name. The schedule visibility setting controls who can see your courses and schedule. You can change that setting under Profile at any time. Your email address and grading breakdown are separate from the Friends feature.</p>
			<h2>Service providers and purchases</h2>
			<p>Supabase hosts account and app data. Cloudflare runs the API and records operational information used to maintain the service and limit abuse. OpenAI processes text submitted for AI scans. Apple processes in-app payments. We use transaction identifiers and scan balances to credit and support purchases.</p>
			<h2>Retention and deletion</h2>
			<p>We keep account data while you use the service. To delete your account and its associated app data, open <strong>Profile → Account → Delete Account</strong>. Operational logs, backups, and service-provider records may remain for a limited period for security, service recovery, or legal obligations. If you used Sign in with Apple, you can also <a href="https://support.apple.com/102571">remove Syllabus Sync from your Apple Account settings</a>.</p>
			<p>If you contact support, we use the information you send to respond and follow up. For privacy questions or requests about your information, email ${contact}.</p>
		`,
	},
	'/support': {
		title: 'Support',
		content: `
			<p>For help with Syllabus Sync, email ${contact}.</p>
			<p>Include your device and iOS version, the screen you were using, and what happened. Leave passwords, complete syllabus documents, and payment details out of your message.</p>
			<h2>Scan credits</h2>
			<p>If a purchase is pending credit, sign in to the account you used for the purchase and select <strong>Profile → AI Scans → Sync purchases</strong>.</p>
			<h2>Account deletion</h2>
			<p>To delete your account, select <strong>Profile → Account → Delete Account</strong>. If you have trouble accessing your account, email support for help.</p>
		`,
	},
};

export function releasePage(path: keyof typeof pages): Response {
	const { title, content } = pages[path];
	return new Response(`<!doctype html>
<html lang="en">
<head>
	<meta charset="utf-8">
	<meta name="viewport" content="width=device-width, initial-scale=1">
	<title>${title} · Syllabus Sync</title>
	<style>
		:root { color-scheme: light dark; }
		body { margin: 0; color: #281f11; background: #fbf7ee; font: 1rem/1.65 system-ui, sans-serif; }
		main { max-width: 42rem; margin: auto; padding: 3.5rem 1.25rem 4.5rem; }
		header p { margin: 0; font-weight: 650; }
		h1 { margin: .2rem 0 1.5rem; font-size: clamp(2.5rem, 8vw, 4rem); line-height: 1.1; letter-spacing: -.045em; }
		h2 { margin: 2rem 0 .4rem; font-size: 1.25rem; }
		p { margin: 0 0 1rem; }
		a { color: #775200; text-underline-offset: .2em; }
		.updated { opacity: .75; }
		nav { border-top: 1px solid #af9a73; margin-top: 2.5rem; padding-top: 1rem; display: flex; gap: 1.25rem; }
		@media (prefers-color-scheme: dark) {
			body { color: #fff3df; background: #211a10; }
			a { color: #f6c65c; }
		}
	</style>
</head>
<body>
	<main>
		<header><p>Syllabus Sync</p><h1>${title}</h1></header>
		${content}
		<nav aria-label="Syllabus Sync information"><a href="/privacy">Privacy Policy</a><a href="/support">Support</a></nav>
	</main>
</body>
</html>`, {
		headers: { 'Content-Type': 'text/html; charset=utf-8', 'Cache-Control': 'public, max-age=300' },
	});
}
