<template>
  <div>
    <span class="before"></span>
    <div
      class="d-flex align-items-center justify-content-center"
      style="width: 100%; height: 100%; display: inline-block; vertical-align: middle;">
      <b-form @submit="on_submit">
        <b-form-group id="input-group-1" label="Имя:" label-for="input-1"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-1"
            v-model="form.name"
            placeholder="Введите имя"
            required
          ></b-form-input>
        </b-form-group>

        <b-form-group id="input-group-6" label="Фамилия:" label-for="input-6"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-6"
            v-model="form.last_name"
            placeholder="Введите фамилию"
            required
          ></b-form-input>
        </b-form-group>

        <b-form-group id="input-group-2" label="Логин:" label-for="input-2"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-2"
            v-model="form.login"
            placeholder="Введите логин"
            required
          ></b-form-input>
        </b-form-group>

        <b-form-group id="input-group-3" label="Эл. почта:" label-for="input-3"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-3"
            v-model="form.email"
            type="email"
            placeholder="Введите эл. почту"
            required
          ></b-form-input>
        </b-form-group>

        <b-form-group id="input-group-4" label="Пароль:" label-for="input-4"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-4"
            :state="check_password"
            aria-describedby="input-live-help password-feedback"
            v-model="form.password"
            placeholder="Введите пароль"
            type="password"
            required
          ></b-form-input>
          <b-form-invalid-feedback id="password-feedback">
            Пароль должен быть не короче 6 символов
          </b-form-invalid-feedback>
        </b-form-group>

        <b-form-group id="input-group-5" label="Подтвердите пароль:" label-for="input-5"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-5"
            :state="check_password_eq"
            aria-describedby="input-live-help password-eq-feedback"
            v-model="form.repeated_password"
            placeholder="Введите пароль еще раз"
            type="password"
            required
          ></b-form-input>

          <b-form-invalid-feedback id="password-eq-feedback">
            Пароли должны совпадать
          </b-form-invalid-feedback>
        </b-form-group>

        <p class="error_logging" v-if="failed"> Ошибка регистрации: {{ failed }}</p>

        <b-button type="submit" block variant="primary">Зарегистрироваться
        </b-button>
        <b-container fluid>
          <router-link to="/auth">Войти</router-link>
        </b-container>
      </b-form>
    </div>
  </div>
</template>

<script>
import {HTTP} from '@/main'
import {log_event} from '@/scouting'

export default {
  data() {
    return {
      form: {
        name: '',
        last_name: '',
        email: '',
        login: '',
        password: '',
        repeated_password: ''
      },
      failed: '',
    }
  },

  computed: {
    check_password() {
      return this.form.password.length >= 6
    },
    check_password_eq() {
      return this.form.password === this.form.repeated_password
    }
  },

  methods: {
    on_submit: function (event) {
      event.preventDefault()
      let global_this = this

      HTTP.post('auth/register', {
        name: this.form.name,
        last_name: this.form.last_name,
        email: this.form.email,
        login: this.form.login,
        password: this.form.password,
      }).then(function (response) {
        global_this.failed = ''
        let token = response.data.access_token
        localStorage.setItem('auth_token', token)
        HTTP.defaults.headers.common['Authorization'] = 'Bearer ' + token;
        global_this.$emit("authenticated", true, true);
        log_event('register')
        global_this.$router.push('main')
      })
        .catch(function (error) {
          console.log(error)
          global_this.failed = error.response.data
        });
    }
  }
}
;
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
