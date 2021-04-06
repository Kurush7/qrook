<template>
  <div style="height: 10%;" class="bg-secondary">
    <b-row class="text-center" align-v="center" align-h="center" style="max-width: 100%">
      <b-col cols="3">
        <img src="@/assets/qrook_white.png" v-on:click="go_home"
             style="height:75px; cursor:pointer">
      </b-col>

      <b-col cols="7">
        <b-row>
          <b-col cols="5" v-if="show_search">
            <b-form-input v-model="search" placeholder="Поиск" @keyup.enter="enterClicked"></b-form-input>
          </b-col>
          <b-col cols="2">
            <b-button v-on:click="setSearch" type="submit" ref="header_search_btn"><b>Найти</b></b-button>
          </b-col>

          <b-col cols="2">
            <b-button v-b-toggle.filter-sidebar v-on:click="$emit('receive_search', search)"><b>Фильтры</b></b-button>
            <!--<b-button v-on:click="show"><b>Фильтры</b></b-button>-->
            <FilterSidebar
              @filters="setFilters"
              @set_search="set_search"
              @search_data="search_data"
              v-bind:search="search"
            ></FilterSidebar>
          </b-col>

        </b-row>
      </b-col>

      <b-col cols="2" class="my-2">
        <b-row align-h="center">
          <b-button pill variant="primary" v-if="!show_account" v-on:click="login" class="my-2">Войти</b-button>
          <b-col v-if="show_account">
            <b-avatar button id="popover-target-1" size="60px"></b-avatar>

            <b-popover target="popover-target-1" triggers="hover" placement="bottom" boundary-padding="1">
              <b-card>
                <b-col>
                  <p>{{ full_name }}</p>
                  <router-link to="/account">Профиль</router-link>
                  <a class="primary-color" v-on:click="logout" style="cursor: pointer;">Выйти</a>
                </b-col>
              </b-card>
            </b-popover>
          </b-col>
        </b-row>
      </b-col>
    </b-row>
  </div>
</template>

<script>
import {HTTP} from '@/main'
import {log_event} from '@/scouting'
import FilterSidebar from "@/components/FilterSidebar.vue";

export default {
  name: "Header",
  props: {
    logged_in: Boolean,
    name: String,
    last_name: String,
    avatar: String
  },

  data() {
    return {
      search: '',
      show_search: true,
    }
  },

  computed: {
    show_account: function () {
      return this.logged_in
    },
    full_name: function () {
      return this.name + ' ' + this.last_name
    },
  },

  created() {
    let token = localStorage.getItem('auth_token')
    if (token !== null) {
      this.$emit("authenticated", true, true);
    }
  },

  methods: {
    search_data() {
      this.$emit('search_data')
    },
    enterClicked() {
      this.$refs.header_search_btn.click()
    },
    set_search(s) {
      this.search = s
    },
    go_home() {
      this.search = ''
      this.$emit("clear_filters");
      this.$router.push('/main')
    },
    setSearch() {
      this.$emit("clear_filters");
      this.$emit("filters", {search: this.search}, true, true);
      this.$emit("search_data");
      log_event('searching', {search: this.search})
    },
    setFilters(filters) {
      this.$emit("filters", filters, false, true);
    },

    login() {
      this.$router.push('/auth')
    },
    logout() {
      log_event('logout')
      localStorage.removeItem('auth_token')
      HTTP.defaults.headers.common.Authorization = undefined
      delete HTTP.defaults.headers.common["Authorization"];
      this.$emit("authenticated", false);
      //this.$router.push('/main')
    },
    edit_account() {
      this.$router.push('/account')
    }
  },

  components: {
    FilterSidebar
  },
};
</script>
