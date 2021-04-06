<template>
  <div id="app">

    <Header v-if="enable_header"
      v-bind:logged_in="logged_in"
      v-bind:name="name"
      v-bind:last_name="last_name"
      v-bind:avatar="avatar"
      @authenticated="setAuthenticated"
      @filters="setFilters"
      @search_data="search_data"
    />

    <router-view
      @authenticated="setAuthenticated"
      @token_expired="tokenExpired"
      @edit_account="onEditAccount"
      @from_home="from_home"
      v-bind:filters="filters"
    />
    <footer id="footer" v-if="enable_footer">
        <div>
          Icons made by <a href="https://www.freepik.com" title="Freepik">Freepik</a> from <a
        href="https://www.flaticon.com/" title="Flaticon">www.flaticon.com</a>
        </div>
    </footer>
  </div>
</template>

<script>
import Header from "@/components/Header.vue";
import {HTTP} from '@/main'

export default {
  name: 'App',
  data() {
    return {
      enable_footer: false,
      logged_in: false,
      name: '',
      last_name: '',
      avatar: '',
      filters: '',
      ignore_push_main: true,
      enable_header: true
    }
  },

  components: {
    Header
  },

  computed: {
  },

  beforeCreate() {
    let token = localStorage.getItem('auth_token')
    let name = this.$router.currentRoute.name
    if (token && name==='Home') this.$router.push('/main')
  },

  created() {
    let token = localStorage.getItem('auth_token')
    if (token) {
      HTTP.defaults.headers.common['Authorization'] = 'Bearer ' + token;
    }

    let name = this.$router.currentRoute.name
    if (name === 'Home') {
      this.enable_header = false
      this.enable_footer = true
    }
    else {
      this.ignore_push_main = false
    }
  },

  methods: {
    search_data() {
      this.$router.push('/main')
    },
    from_home() {
      this.ignore_push_main = false
      this.enable_header = true
      this.enable_footer = false
      this.setFilters({first_time: true}, true, true)
    },
    setFilters(filters, add=false, push=false) {
      if (add) this.filters = Object.assign({}, this.filters, filters);
      else this.filters = filters
      //if (push && !this.ignore_push_main)  this.$router.push('/main')
    },

    onEditAccount() {
      this.setAuthenticated(true, true)
    },

    setAuthenticated(status, load_data) {
      this.logged_in = status;
      if (load_data) {
        let global_this = this
        HTTP.get('auth/user_info', {})
          .then(function (response) {
            global_this.name = response.data.name
            global_this.last_name = response.data.last_name
            global_this.avatar = response.data.avatar
          })
          .catch(function (error) {
            console.log(error.response)
            let reason = error.response.data
            if (reason === 'token expired') {
              global_this.tokenExpired()
            }
          });
      }
    },
    tokenExpired() {
      this.logged_in = false;
      this.$router.push('auth')
    },
  }
};
</script>

<style>
#app {
  font-family: 'Avenir', Helvetica, Arial, sans-serif;
  -webkit-font-smoothing: antialiased;
  -moz-osx-font-smoothing: grayscale;
  text-align: center;
  color: #2c3e50;
  margin-top: 0;
}

#footer {
  background: #cccccc;
  position: fixed;
  left: 0px;
  bottom: 0px;
  height: 30px;
  width: 100%;
}

</style>
