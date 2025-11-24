<script setup>
</script>

<template>
	<div class="home flex w-full h-dvh gap-8 flex-col items-center justify-center">
        <div class="relative w-72 h-72">
            <div class="bg-gradient-to-r from-red-600 to-red-800 rounded-full absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-96 h-96 blur-3xl z-[-1]"></div>
            <img src="/acanthis-logo.png" alt="Acanthis Logo" class="absolute top-1/2 left-1/2 transform -translate-x-1/2 -translate-y-1/2 w-72 h-72" />
        </div>
        <div class="flex flex-col items-center">
            <div class="text-4xl lg:text-6xl md:w-[44rem] text-pretty font-bold text-center">Your best pal for validating data in Flutter</div>
            <div class="my-4 lg:my-8 text-xl lg:text-2xl md:w-[44rem] text-pretty text-gray-300 text-center">
                Validate your data with ease and confidence with <b>50+</b> validators at your disposal.
            </div>
            <div class="flex flex-col lg:flex-row justify-center items-center gap-4">
                <a href="/introduction.html" class="bg-red-600 px-8 py-4 rounded-full text-white font-semibold">Get Started</a>
                <a href="https://discord.gg/zydgnJ3ksJ" class="px-8 py-4 font-semibold">Join the community</a>
            </div>
        </div>
  	</div>
</template>

<style scoped>
.VPNavBar {
	background-color: transparent !important;
}
#learn-more {
    color: rgba(255, 255, 255, 0.7);
}
.vp-doc a {
    color: white;
    text-decoration: none;
}
.vp-doc a.text-black {
    color: rgb(27, 27, 31);
}
p {
	margin: 0 !important;
}
.results{
	line-height: 1rem;
}
ol {
	padding: 0;
}
</style>