<template>
  <div>
    <b-card class="mb-3" style="width: 600px; margin-left: 10px; margin-top: 10px;" img-left>
      <b-row>
        <b-col>
          <img v-if="!skin_image" :src="require('@/assets/default_series.png')"
               width="200px" height="300px"></img>
          <img v-if="skin_image" :src="skin_image" width="200px" height="300px"></img>
        </b-col>
        <b-col>
          <b-card-body :title="name">
            <b-card-text>
              <b-row v-if="finished">
                <span class="text-muted">Закончена:&nbsp</span>
                <span>{{ finished }}</span>
              </b-row>
              <b-row v-if="books_cnt">
                <span class="text-muted">Количество книг:&nbsp</span>
                <span>{{ books_cnt }}</span>
              </b-row>

              <b-row>
                <div v-for="(author, i) of authors">
                  <img src="@/assets/pen_icon.png" width="25px">
                  <router-link :to="'/author/' + author.id" class="bookLink">{{ author.name }}</router-link>
                </div>
              </b-row>
            </b-card-text>
          </b-card-body>
        </b-col>
      </b-row>
    </b-card>

    <b-card style=" margin-left: 10px; max-width: 95%">
      <b-row>
        <b-card-body title="О серии">
          <b-card-text>
            <pre>{{ description }}</pre>
          </b-card-text>
        </b-card-body>
      </b-row>
    </b-card>
    <div style="margin-top: 10px">
      <h4 align="center">Книги серии:</h4>
      <div>
        <PreviewCollection
          v-bind:filters="filters">
        </PreviewCollection>
      </div>
    </div>
  </div>
</template>

<script>
import {HTTP} from '@/main'
import {log_event} from '@/scouting'
import PreviewCollection from "@/components/PreviewCollection.vue";

export default {
  name: "Series",
  data() {
    return {
      id: null,
      info: {},
      filters: {}
    }
  },

  watch: {
    '$route.params.id': {
      handler: function (id) {
        this.load_data();
        this.filters = {series_id: this.id, find_book:true, sort:'series_order'}
      },
      deep: true,
      immediate: true
    }
  },

  created() {
    //this.load_data()
    this.filters = {series_id: this.id, find_book:true, sort:'series_order'}
  },

  computed: {
    authors() {
      // todo add '...' if there are more authors than possible to show
            if (!this.info) {
        return null
      }
      let data = []
      let x = this.info['authors']
      if (!x) {
        return []
      }
      for (let a of x) {
        a = {id: a.id, name: this.parse_author(a['name'])}
        data.push(a)
      }
      return data
    },


    skin_image() {
      if (!this.info) {
        return null
      }
      let a = this.info['skin_image']
      if (a) {
        return a
      }
      return null
    },

    name() {
      if (!this.info) {
        return null
      }
      return this.info['title']
    },

    books_cnt() {
      if (!this.info) {
        return null
      }
      return this.info['books_count']
    },

    finished() {
      if (!this.info) {
        return null
      }
      // todo check that works
      let a = this.info['is_finished']
      if (a === true) {
        return 'да'
      } else if (a === false) {
        return 'нет'
      } else {
        return 'неизвестно'
      }
    },


    description() {
            if (!this.info) {
        return null
      }
      let a = this.info['description']
      if (a) {
        return a
      }
      return 'Информации о серии книг нет'
    }

  },

  components: {
    PreviewCollection
  },

  methods: {
    load_data() {
      this.id = this.$route.params.id
      let global_this = this
      HTTP.get('search/series', {params: {id: this.id}}).then(function (response) {
        global_this.failed = false
        global_this.info = response.data
        log_event('view_series', {series_id: Number(global_this.id)})
      })
        .catch(function (error) {
          console.log(error.message)
          global_this.failed = true
        });
    },

    parse_author(a) {
      if (a.length > 20) {
        a = a.split(' ')
        for (let x of a.slice(1)) {
          if (x === '') continue
          a[0] += ' ' + x[0] + '.'
        }
        a = a[0]
      }
      return a
    },
  },

  props: ['info_props']
}
</script>

<style>
pre {
  word-wrap: break-word; /* Internet Explorer 5.5+ поддерживается в IE, Safari, и Firefox 3.1.*/
  margin: 10px;
  text-align: left;
  white-space: pre-line;
}
</style>
