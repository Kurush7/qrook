// The Vue build version to load with the `import` command
// (runtime-only or standalone) has been set in webpack.base.conf with an alias.
import BootstrapVue from 'bootstrap-vue';
import 'bootstrap/dist/css/bootstrap.css';
import 'bootstrap-vue/dist/bootstrap-vue.css';

import Vue from 'vue';
import App from './App';
import router from './router';

import {store} from './store';

let axios = require('axios');
export const HTTP = axios.create({
  baseURL: 'http://localhost/',
  headers: {
    "Access-Control-Allow-Origin": "*",
    "Access-Control-Allow-Methods": "GET, POST, PATCH, PUT, DELETE, OPTIONS",
    "Access-Control-Allow-Headers": "Origin, Content-Type, X-Auth-Token"
  }
})

Vue.use(BootstrapVue);

import CountryFlag from 'vue-country-flag'
Vue.component('vue-country-flag', CountryFlag)

import VirtualCollection from 'vue-virtual-collection'
Vue.use(VirtualCollection)

Vue.config.productionTip = false;
/* eslint-disable no-new */
new Vue({
  el: '#app',
  store,
  router,
  components: {App},
  template: '<App/>',
});
