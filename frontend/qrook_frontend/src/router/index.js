import Vue from 'vue';
import Router from 'vue-router';

import Home from '@/views/Home';
import Auth from '@/views/Auth';
import Register from '@/views/Register';
import Main from '@/views/Main';
import Account from '@/views/Account';
import Book from '@/views/Book';
import Author from '@/views/Author';
import Series from '@/views/Series';
import EditProfile from '@/views/EditProfile';

Vue.use(Router);

export default new Router({
  routes: [
    {
      path: '/',
      redirect: '/home'
    },
    {
      path: '/home',
      name: 'Home',
      component: Home,
    },
    {
      path: '/auth',
      name: 'Auth',
      component: Auth,
    },
    {
      path: '/register',
      name: 'Register',
      component: Register,
    },
    {
      path: '/main',
      name: 'Main',
      component: Main,
    },
    {
      path: '/account',
      name: 'Account',
      component: Account,
    },
    {
      path: '/book/:id',
      component: Book
    },
    {
      path: '/author/:id',
      component: Author
    },
    {
      path: '/series/:id',
      component: Series
    },
    {
      path: '/edit_profile',
      name: 'edit_profile',
      component: EditProfile,
      props: true
    },
  ],
});
