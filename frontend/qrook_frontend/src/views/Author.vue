<template>
  <div>
    <b-card class="mb-3" style="width: 600px; margin-left: 10px; margin-top: 10px;" img-left>
      <b-row>
        <b-col>
          <img v-if="!photo" :src="require('@/assets/author_default.png')"
               width="200px" height="300px"></img>
          <img v-if="photo" :src="photo" width="200px" height="300px"></img>
        </b-col>
        <b-col>
          <b-card-body :title="name">
            <b-card-text>
              <b-row v-if="sex">
                <span class="text-muted">Пол:&nbsp</span>
                <span>{{ sex }}</span>
              </b-row>
              <b-row v-if="bdate">
                <span class="text-muted">Дата рождения:&nbsp</span>
                <span>{{ bdate }}</span>
              </b-row>
            </b-card-text>
          </b-card-body>
        </b-col>
      </b-row>
    </b-card>

    <b-card style=" margin-left: 10px; max-width: 95%">
      <b-row>
        <b-card-body title="Об авторе">
          <b-card-text>
            <pre align="left">>{{ description }}</pre>
          </b-card-text>
        </b-card-body>
      </b-row>
    </b-card>
    <div style="margin-top: 10px">
      <h4 align="center">Написанные книги:</h4>
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
  name: "Author",
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
        this.filters = {author_id: this.id, find_book:true, find_series:true}
      },
      deep: true,
      immediate: true
    }
  },

  created() {
    //this.load_data()
    this.filters = {author_id: this.id, find_book:true, find_series:true}
  },

  computed: {
    sex() {
      return this.info['sex']
    },
    photo() {
      let a = this.info['photo']
      if (a) {
        return a
      }
      return null
    },
    name() {
      return this.info['name']
    },

    bdate() {
      let bd = this.info['birthdate']
      if (!bd) {
        return null
      }
      return (new Date(bd)).toLocaleDateString()
    },

    description() {
      let a = this.info['description']
      if (a) {
        return a
      }
      return 'Информации об авторе нет'
    }

  },

  components: {
    PreviewCollection
  },

  methods: {
    load_data() {
      this.id = this.$route.params.id
      let global_this = this
      HTTP.get('search/author', {params: {id: this.id}}).then(function (response) {
        global_this.failed = false
        global_this.info = response.data
        log_event('view_author', {author_id: Number(global_this.id)})
      })
        .catch(function (error) {
          console.log(error.message)
          global_this.failed = true
        });
    }
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
