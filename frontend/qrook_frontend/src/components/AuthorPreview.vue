<template>
  <div>
    <b-card
      border-variant="warning"
      no-body
      style="height:300px; width:200px; border-width: 3px"
    >
      <div class="card-header" style="height: 300px">
        <div v-if="!photo"><img :src="require('@/assets/author_default.png')"
                                     width="150px" height="225px"></div>
        <div v-if="photo"><img :src="photo" width="150px" height="225px"></div>
        <div>
          <router-link :to="'/author/' + author_id" class="bookLink">{{ title }}</router-link>
        </div>
      </div>
    </b-card>
  </div>
</template>

<script>
export default {
  name: "AuthorPreview",
  data() {
    return {
      id: 0,
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
    photo() {
            if (!this.info) return null
      let a = this.info['photo']
      if (a) {
        return a
      }
      return null
    },

    title() {
            if (!this.info) return null
      let t = this.info['name']
      if (t.length > 51) {
        t = t.slice(0, 48) + '...'
      }
      return t
    },

    title_lines_busy() {
            if (!this.title) return 0
      return Math.ceil(this.title.length / 17)
    },

    author_id() {
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
