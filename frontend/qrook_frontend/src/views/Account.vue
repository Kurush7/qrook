<template>
  <div>
    <b-card class="mb-3" style="width: 600px; margin-left: 10px; margin-top: 10px;" img-left>
      <b-row>
        <b-col>
          <img v-if="!avatar_computed" :src="require('@/assets/default_user.png')"
               width="200px" height="300px">
          <img v-if="avatar_computed" :src="avatar_computed" width="200px" height="300px">
        </b-col>
        <b-col>
          <b-card-body :title="full_name">
            <b-card-text>
              <b-row v-if="email">
                <span class="text-muted">Почта:&nbsp</span>
                <span>{{ email }}</span>
              </b-row>
              <b-row v-if="login">
                <span class="text-muted">Логин:&nbsp</span>
                <span>{{ login }}</span>
              </b-row>
              <b-row v-if="password">
                <span class="text-muted">Пароль:&nbsp</span>
                <span>{{ password }}</span>
              </b-row>
            </b-card-text>
          </b-card-body>
          <a v-on:click="edit_profile" style="color:dodgerblue; cursor: pointer;" >редактировать профиль</a>
        </b-col>
      </b-row>
    </b-card>
  </div>
</template>

<script>
import {HTTP} from '@/main'
import {log_event} from '@/scouting'

export default {
  data() {
    return {
      name: '',
      last_name: '',
      email: '',
      login: '',
      password: '',
      avatar: '',
    }
  },

  computed: {
    avatar_computed() {
      if (!this.avatar)
        return null
      return this.avatar
    },

    full_name() {
      return this.name + ' ' + this.last_name
    }
  },

  created() {
    let global_this = this
    HTTP.get('auth/user_info', {})
      .then(function (response) {
        global_this.name = response.data.name
        global_this.last_name = response.data.last_name
        global_this.email = response.data.email
        global_this.login = response.data.login
        global_this.password = response.data.password
        global_this.avatar = response.data.avatar
        log_event('view_account')
      })
      .catch(function (error) {
        console.log(error.response)
        let reason = error.response.data
        if (reason === 'token expired') {
          global_this.$emit("token_expired");
        }
      });
  },

  methods: {
    edit_profile() {
      this.$router.push({ name: 'edit_profile', params: this.$data})
    }
  }
};
</script>
