<template>
  <div>
    <b-card
      border-variant="success"
      no-body
      style="height:300px; width:200px; border-width: 3px"
    >
      <div class="card-header">
        <div v-if="!series_image"><img :src="require('@/assets/default_series.png')"
                                       width="110px" height="165px"></div>
        <div v-if="series_image"><img :src="series_image" width="110px" height="165px"></div>
        <div>
          <router-link :to="'/series/' + series_id" class="bookLink">{{ title }}</router-link>
        </div>
        <div>
          <span class="text-muted">Число книг:</span>
          <span>{{ books_cnt }}</span>
        </div>
      </div>
      <b-card-text>
        <div v-for="(author, i) of authors">
          <img src="@/assets/pen_icon.png" width="25px">
          <router-link :to="'/author/' + author.id" class="bookLink">{{ author.name }}</router-link>
        </div>
      </b-card-text>
    </b-card>
  </div>
</template>

<script>
export default {
  name: "SeriesPreview",
  data() {
    return {
      id: 0,
      authors_limit: 1
    }
  },

  methods: {
    getWidth() {
      return this.$refs.app.clientWidth
    },
    getHeight() {
      return this.$refs.app.clientHeight
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

  computed: {
    series_image() {
      if (!this.info) return null
      let a = this.info['skin_image']
      if (a) {
        return a
      }
      return null
    },

    title() {
      if (!this.info) return null
      let t = this.info['title']
      if (t.length > 34) {
        t = t.slice(0, 31) + '...'
      }
      return t
    },

    books_cnt() {
      if (!this.info) return null
      let x = this.info['books_count']
      return x
    },

    title_lines_busy() {
      if (!this.title) return 0
      return Math.ceil(this.title.length / 17)
    },

    // todo add finished flag & books count

    authors() {
      if (!this.info) return []
      // todo add '...' if there are more authors than possible to show
      let data = []
      let free = 4 - this.title_lines_busy
      free = Math.min(this.authors_limit, free)
      for (let a of this.info['authors'].slice(0, free)) {
        a = {id: a.id, name: this.parse_author(a['name'])}
        data.push(a)
      }
      return data
    },

    series_id() {
      if (!this.info) return null
      return this.info.id
    }
  },

  props: ['info']
}
</script>

<style>
.bookLink {
  color: #2c3e50;
  text-decoration: none;
  font-size: 1em;
  position: relative;
  transition: all 0.6s;
}

.bookLink:before {
  content: "";
  width: 0;
  height: 0.1em;
  position: absolute;
  bottom: 0;
  left: 50%;
  transition: all 0.3s;
}

.bookLink:hover:before {
  width: 100%;
  left: 0;
}

</style>
