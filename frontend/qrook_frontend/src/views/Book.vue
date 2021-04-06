<template>
  <div>
    <div class="row" style="max-width: 100%">
      <b-card class="mb-3" style="width: 600px; margin-left: 30px; margin-top: 10px;" img-left>
        <b-row>
          <b-col>
            <img v-if="!skin_image" :src="require('@/assets/default_book.png')"
                 width="200px" height="300px"></img>
            <img v-if="skin_image" :src="skin_image" width="200px" height="300px"></img>
          </b-col>
          <b-col>
            <b-card-body :title="title">
              <b-card-text>

                <b-row v-if="book_order">
                  <span class="text-muted">номер книги в серии:&nbsp</span>
                  <span>{{ book_order }}</span>
                </b-row>
                <b-row v-if="series">
                  <img src="@/assets/series_link.png" width="25px" height="25px">
                  <router-link :to="'/series/' + series.id" class="bookLink">:&nbsp {{ series.title }}</router-link>
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

      <b-card class="mb-3" style="width: 600px; margin-left: 10px; margin-top: 10px;" img-left>
        <b-row>
          <b-col>
            <b-card-body title="Публикации">
              <b-dropdown text="Left align" variant="outline-primary" style="margin-bottom: 10px">
                <template #button-content>
                  {{ publ_dropdown_title }}
                  <country-flag :country=publ_dropdown_lang size='normal'/>
                </template>

                <div v-for="(pub, i) of publications">
                  <b-dropdown-item href="#" v-on:click=change_publication(i)>
                    {{ publ_repr(pub) }}
                    <country-flag :country=publ_lang(pub) size='normal'/>
                  </b-dropdown-item>
                </div>
              </b-dropdown>

              <div v-for="(info, i) of publ_info">
                <b-row>
                  <span class="text-muted">{{ i }}:&nbsp</span>
                  <span>{{ info }}</span>
                </b-row>
              </div>

              <div style="margin-bottom: 10px; margin-top: 20px">
                Скачать книгу:
              </div>
              <b-button-group>
                <div v-for="(file, i) of publ_files" style="margin-left: 10px">
                  <b-button
                    v-on:click=download(i)
                    variant="outline-primary">{{ file.file_type }}
                  </b-button>
                </div>
              </b-button-group>
              <div v-if="download_error" style="margin-bottom: 10px; margin-top: 20px; color: firebrick">
                {{ download_error }}
              </div>

            </b-card-body>
          </b-col>
        </b-row>
      </b-card>
    </div>


    <b-card style=" margin-left: 10px; max-width: 95%">
      <b-row>
        <b-card-body title="О книге">
          <b-card-text>
            <pre>{{ description }}</pre>
          </b-card-text>
        </b-card-body>
      </b-row>
    </b-card>
  </div>
</template>

<script>
import {HTTP} from '@/main'
import {log_event} from '@/scouting'
import CountryFlag from 'vue-country-flag'

// todo нет публикаций, пустое описание, нет файлов
export default {
  name: "Book",
  data() {
    return {
      id: null,
      info: {},
      filters: {},
      publication: undefined,
      download_error: undefined
    }
  },

  components: {
    CountryFlag
  },
  watch: {
    '$route.params.id': {
      handler: function (id) {
        this.load_data();
        this.download_error = undefined
      },
      deep: true,
      immediate: true
    }
  },

  created() {
    //this.load_data()
  },

  computed: {
    book_order() {
      if (!this.info) return null
      let a = this.info['book_order']
      if (a) {
        return a
      }
      return null
    },

    series() {
      if (!this.info) return null
      let s = this.info['series']
      if (s) {
        return s
      }
      return null
    },

    publ_files() {
      if (!this.publication) return undefined
      return this.publication.files
    },
    publ_info() {
      if (!this.publication) return undefined
      let info = this.publication.info
      if (this.publication.isbn) {
        info['ISBN'] = this.publication.isbn
      }
      if (this.publication.isbn13) {
        info['ISBN-13'] = this.publication.isbn13
      }
      if (this.publication.publication_year) {
        info['год публикации'] = this.publication.publication_year
      }
      return info
    },
    publ_dropdown_title() {
      return this.publ_repr(this.publication)
    },
    publ_dropdown_lang() {
      return this.publ_lang(this.publication)
    },
    publications() {
      if (!this.info) {
        return null
      }
      let data = this.info['publications']
      if (!data) {
        return []
      }
      return data
    },

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

    title() {
      if (!this.info) {
        return null
      }
      return this.info['title']
    },

    description() {
      if (!this.info) {
        return null
      }
      let a = this.info['description']
      if (a) {
        return a
      }
      return 'Информации о книге нет'
    }

  },

  methods: {
    language_to_country_code(code) {
      switch (code) {
        case 'ru':
          return 'ru'
        case 'en':
          return 'gb'
      }
    },

    download(file_num) {
      let file = this.publication.files[file_num]
      let path = 'files/book/' + file.file_path
      let global_this = this
      HTTP.get(path, {responseType: "blob"})
        .then(response => {
          global_this.download_error = undefined
          const url = window.URL.createObjectURL(new Blob([response.data]));
          const link = document.createElement("a");
          link.href = url;
          link.setAttribute("download", file.file_path); //or any other extension
          document.body.appendChild(link);
          link.click();
          document.body.removeChild(link)
          log_event('download_book', {book_id: global_this.id, file: file})
        }).catch(function (error) {
        let status = error.response.status
        if (status === 401) {
          global_this.download_error = 'чтобы скачать книгу, необходимо авторизоваться'
        } else {
          global_this.download_error = 'файл недоступен'
        }
      });
    },

    change_publication(publ_num) {
      this.publication = this.publications[publ_num]
    },

    publ_repr(publ) {
      if (!publ) return
      return this.title + ' ' + publ['language_code']
    },
    publ_lang(publ) {
      if (!publ) return
      return this.language_to_country_code(publ['language_code'])
    },

    load_data() {
      this.id = this.$route.params.id
      let global_this = this
      HTTP.get('search/book', {params: {id: this.id}}).then(function (response) {
        global_this.failed = false
        global_this.info = response.data
        global_this.publication = response.data['publications'][0]
        log_event('view_book', {book_id: Number(global_this.id)})
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
