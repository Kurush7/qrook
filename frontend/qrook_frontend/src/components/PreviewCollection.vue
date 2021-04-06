<template>
  <div>
    <VirtualCollection
      id="virt-coll"
      v-if="have_data"
      :cellSizeAndPositionGetter="cellSizeAndPositionGetter"
      :collection="items"
      :height="height"
      :width="width"
      v-on:scrolled-to-bottom-range="upload_data"
      :scrollToBottomRange="1000"
      >
      <!--v-on:scrolled-to-top="scrollTop"!-->
      <div slot="cell" slot-scope="props">
        <ItemPreview
          v-bind:info=props.data>
        </ItemPreview>
      </div>
    </VirtualCollection>
    <div v-if="!have_data" style="margin-top: 50px">
      Информация по запросу не найдена
    </div>
  </div>
</template>


<script>
import ItemPreview from "@/components/ItemPreview.vue";
import {HTTP} from '@/main'
import {log_event} from '@/scouting'

export default {
  data() {
    return {
      offset: 0,
      limit: 100,
      all_read: false,

      width: window.innerWidth,
      height: window.innerHeight,
      //items: Array.from({length: 100}, (_, index) => (
      //  {data:{book_title: "Очень Страшная Книга", authors: ['Автор Авторович'], id: index}})),
      items: [],
      failed: false,

      place_data: {
        per_row: null,
        item_width: null,
        item_height: null,
        x_first: null,
        x_space: null,
        y_first: null,
        y_space: null
      }
    }
  },

  created() {
    window.addEventListener('resize', this.updateMainSize);
    this.upload_data()
    setTimeout(() => {  this.updateMainSize() }, 300);
  },

    watch: {
    filters: {
      handler: function (id) {
        this.offset = 0
        this.all_read = false
        this.items = []
        this.upload_data()
      },
      deep: true,
      immediate: true
    }
  },

  computed: {
    have_data() {
      return this.items.length > 0
    }
  },


  methods: {
    upload_data() {
      if (this.all_read) {
        return
      }

      // todo add: show some text about "no info found"

      let global_this = this
      let params = {offset: this.offset, limit: this.limit}
      params = Object.assign({}, params, this.filters);
      HTTP.get('search/main', {params: params}).then(function (response) {
        global_this.failed = false
        let items = response.data
        for (let i = 0; i < items.length; ++i) {
          items[i] = {data: items[i]}
        }

        //if (items.length < global_this.limit) {
        global_this.all_read = items.length === 0

        global_this.items.push.apply(global_this.items, items)
        global_this.$forceUpdate();
      })
        .catch(function (error) {
          console.log(error.message)
          global_this.failed = true
        });

      this.offset += this.limit
      this.$forceUpdate();
    },

    define_place_params(item) {
      this.place_data.item_height = 300
      this.place_data.item_width = 200

      let width = this.place_data.item_width
      this.place_data.per_row = Math.floor(this.width / (width * 1.1))
      this.place_data.x_first = 10
      this.place_data.x_space = (this.width * 0.98 - 2 * this.place_data.x_first - this.place_data.per_row * width) / (this.place_data.per_row - 1)
      this.place_data.y_first = 10
      this.place_data.y_space = 10
    },

    cellSizeAndPositionGetter(item, index) {
      if (this.place_data.per_row === null) {
        this.define_place_params(item)
      }
      let width = this.place_data.item_width
      let height = this.place_data.item_height
      let per_row = this.place_data.per_row
      let x_first = this.place_data.x_first
      let y_first = this.place_data.y_first
      let x_space = this.place_data.x_space
      let y_space = this.place_data.y_space
      return {
        width: width,
        height: height,
        x: x_first + (index % per_row) * (width + x_space),
        y: y_first + Math.floor(index / per_row) * (height + y_space)
      }
    },

    updateMainSize() {
      this.width = document.getElementById("virt-coll").parentNode.parentElement.clientWidth
      this.height = document.getElementById("virt-coll").parentNode.parentElement.clientHeight
      this.place_data.per_row = null
      this.$forceUpdate();
    }
  },

  components: {
    ItemPreview
  },

  props: ['filters']
}
</script>
