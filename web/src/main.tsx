import React from 'react'
import ReactDOM from 'react-dom/client'
import './index.css'
import { BrowserRouter, Routes, Route, Navigate } from 'react-router-dom'
import { createClient, Provider } from 'urql'
import { GraphqlView } from './pages/graphql-view'
import { TodoForm } from './pages/todo/todo-form-request'

const client = createClient({
  url: 'https://5mg9i4ce1h.execute-api.ap-south-1.amazonaws.com/query',
  fetchOptions: {
    headers: {
      AuthUserId: '1',
      'Accept-Language': 'pl',
    },
  },
})

ReactDOM.createRoot(document.getElementById('root')!).render(
  <React.StrictMode>
    <Provider value={client}>
      <App />
    </Provider>
  </React.StrictMode>
)

function App() {
  return (
    <BrowserRouter>
      <Routes>
        <Route path="/" element={<Navigate to="/view" />} />
        <Route path="view" element={<GraphqlView />} />
        <Route path="todo" element={<TodoForm />} />
      </Routes>
    </BrowserRouter>
  )
}
