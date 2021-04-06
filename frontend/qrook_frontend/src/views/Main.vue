<template>
  <div>
    <PreviewCollection
      v-bind:filters="search_filters"></PreviewCollection>
  </div>
</template>


<script>
import {log_event} from '@/scouting'
import PreviewCollection from "@/components/PreviewCollection.vue";

export default {
  components: {
    PreviewCollection
  },

  computed: {
    search_filters() {
      let x = this.filters
      return x
    }
  },

  props: ['filters']
}
</script>
