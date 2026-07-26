import { defineConfig } from 'vite';
import { vueConfig } from '@nativescript/vite/vue';;

export default defineConfig(({ mode }) => vueConfig({ mode }));
