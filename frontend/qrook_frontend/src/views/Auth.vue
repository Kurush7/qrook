<template>
  <div>
    <span class="before"></span>
    <div
      class="d-flex align-items-center justify-content-center"
      style="width: 100%; height: 100%; display: inline-block; vertical-align: middle;">
      <b-form @submit="onSubmit">
        <b-form-group id="input-group-1" label="Логин:" label-for="input-1"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-1"
            v-model="form.login"
            placeholder="Введите логин"
            required
          ></b-form-input>
        </b-form-group>

        <b-form-group id="input-group-2" label="Пароль:" label-for="input-2"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-2"
            v-model="form.password"
            placeholder="Введите пароль"
            required
          ></b-form-input>
        </b-form-group>

        <p class="error_logging" v-if="failed"> Некорректные логин или пароль </p>

        <b-button type="submit" block variant="primary">Войти</b-button>
        <b-container fluid>
          <router-link to="/register">Зарегистрироваться</router-link>
        </b-container>
      </b-form>
    </div>
  </div>
</template>

<script>
import {HTTP} from '@/main'
import {log_event} from '@/scouting'
import {mapActions, mapState} from 'vuex'

export default {
  data() {
    return {
      form: {
        login: '',
        password: '',
      },
      failed: false,
    }
  },

  computed: {
    isError() {
      return this.failed !== '';
    },
    ...mapState('account', ['status'])
  },

  methods: {
    ...mapActions('account', ['login', 'logout']),
    onSubmit(event) {
      event.preventDefault()
      let global_this = this
      HTTP.post('auth/login', {
        login: this.form.login,
        password: this.form.password,
      }).then(function (response) {
        global_this.failed = false
        let token = response.data.access_token

        localStorage.setItem('auth_token', token)
        HTTP.defaults.headers.common['Authorization'] = 'Bearer ' + token;
        global_this.$emit("authenticated", true, true);

        //global_this.$router.push('main')
        global_this.$router.go(-1)
        log_event('login')
      })
        .catch(function (error) {
          console.log(error.message)
          global_this.failed = true
        });
    },
  },
};
</script>

<style>
.error_logging {
  color: var(--red);
}

.before {
  display: inline-block;
  height: 100%;
  vertical-align: middle;
}
</style>
