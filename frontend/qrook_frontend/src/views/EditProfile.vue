<template>
  <div>
    <span class="before"></span>
    <div
      class="d-flex align-items-center justify-content-center"
      style="width: 100%; height: 100%; display: inline-block; vertical-align: middle;">
      <b-form @submit="on_submit">

        <b-form-group id="input-group-7" label="Фото:" label-for="input-7"
                      label-align="right" content-cols="8">
          <b-form-file
            style="max-width: 400px"
            id="file"
            placeholder="Выберите фото"
          ></b-form-file>
        </b-form-group>

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
            disabled
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

        <b-form-group id="input-group-4" label="Текущий пароль:" label-for="input-4"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-4"
            aria-describedby="input-live-help password-feedback"
            v-model="form.old_password"
            placeholder="Введите текущий пароль"
            type="password"
            required
          ></b-form-input>
        </b-form-group>

        <b-form-group id="input-group-4" label="Новый пароль:" label-for="input-4"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-4"
            :state="check_password"
            aria-describedby="input-live-help password-feedback"
            v-model="form.new_password"
            placeholder="Введите новый пароль"
            type="password"
          ></b-form-input>
          <div v-if="this.form.new_password.length === 0" class="text-muted" style="font-size: 14px">*Не заполняйте,
            если не хотите менять пароль
          </div>
          <b-form-invalid-feedback id="password-feedback">
            Пароль должен быть не короче 6 символов
          </b-form-invalid-feedback>
        </b-form-group>

        <b-form-group id="input-group-5" label="Подтвердите новый пароль:" label-for="input-5"
                      label-align="right" content-cols="8">
          <b-form-input
            id="input-5"
            :state="check_password_eq"
            aria-describedby="input-live-help password-eq-feedback"
            v-model="form.repeated_password"
            placeholder="Введите пароль еще раз"
            type="password"
          ></b-form-input>

          <b-form-invalid-feedback id="password-eq-feedback">
            Пароли должны совпадать
          </b-form-invalid-feedback>
        </b-form-group>

        <p class="error_logging" v-if="failed"> Некорректный пароль </p>

        <b-button type="submit" value="update" block variant="primary">Обновить профиль</b-button>
        <b-button type="submit" value="delete" block variant="danger">Удалить профиль</b-button>
        <div>
          <a v-on:click="$router.go(-1)" style="color:black; cursor: pointer;">отмена</a>
        </div>
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
        old_password: '',
        new_password: '',
        repeated_password: ''
      },
      failed: '',
    }
  },
  props: ["name", "last_name", "login", "password", "email"],

  created() {
    // this.form.name = this.name
    // this.form.last_name = this.last_name
    // this.form.login = this.login
    // this.form.email = this.email
    let global_this = this
    HTTP.get('auth/user_info', {})
      .then(function (response) {
        global_this.form.name = response.data.name
        global_this.form.last_name = response.data.last_name
        global_this.form.email = response.data.email
        global_this.form.login = response.data.login
      })
      .catch(function (error) {
        console.log(error.response)
        let reason = error.response.data
        if (reason === 'token expired') {
          global_this.$emit("token_expired");
        }
      });
  },

  computed: {
    check_password() {
      return this.form.new_password.length === 0 || this.form.new_password.length >= 6
    },
    check_password_eq() {
      return this.form.new_password === this.form.repeated_password
    }
  },

  methods: {
    on_delete: function (event) {
      if (confirm('Вы уверены, что хотите удалить аккаунт?')) {
        if (confirm('... точно уверены?')) {
          let global_this = this
          HTTP.delete('auth/delete_profile',
          ).then(function (response) {
            global_this.failed = ''
            global_this.$emit("authenticated", false, false);
            global_this.$router.push('main')
            log_event('delete_account')
          })
            .catch(function (error) {
              console.log(error)
              global_this.failed = error.response.data
            });
        }
      }
    },

    on_submit: function (event) {
      let action = event.submitter.value
      if (action === 'delete') {
        this.on_delete(event)
        return
      }

      event.preventDefault()
      let global_this = this
      let data = new FormData()
      // todo check that file exists
      let imagefile = document.querySelector('#file')
      data.append('avatar', imagefile.files[0])
      data.append('name', this.form.name)
      data.append('last_name', this.form.last_name)
      data.append('email', this.form.email)
      data.append('login', this.form.login)
      data.append('password', this.form.old_password)
      data.append('new_password', this.form.new_password)

      HTTP.post('auth/edit_profile',
        data
      ).then(function (response) {
        global_this.failed = ''
        global_this.$emit('edit_account')
        global_this.$router.push('main')
        log_event('edit_profile')
      })
        .catch(function (error) {
          console.log(error)
          global_this.failed = error.response.data
        });
    },
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
