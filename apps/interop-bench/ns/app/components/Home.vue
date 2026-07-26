<template>
    <Frame>
        <Page>
            <ActionBar>
                <Label text="Interop Bench"/>
            </ActionBar>

            <StackLayout class="p-4">
                <Label class="text-lg text-center" :text="status" />
                <Label class="text-xs" :text="resultText" textWrap="true" />
            </StackLayout>
        </Page>
    </Frame>
</template>

<script setup lang="ts">
  import { onMounted, ref } from 'nativescript-vue'
  import { runAll } from '../interop'

  const status = ref('starting…')
  const resultText = ref('')

  onMounted(() => {
    setTimeout(async () => {
      try {
        resultText.value = await runAll((id) => {
          status.value = `running ${id}…`
        })
        status.value = 'done'
      } catch (err) {
        resultText.value = `INTEROPJSON:{"fw":"nativescript","error":"${String(err).replace(/"/g, "'")}"}`
        status.value = 'error'
      }
    }, 500)
  })
</script>
