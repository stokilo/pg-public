import * as React from 'react'
import Avatar from '@mui/material/Avatar'
import Button from '@mui/material/Button'
import CssBaseline from '@mui/material/CssBaseline'
import TextField from '@mui/material/TextField'
import Paper from '@mui/material/Paper'
import Box from '@mui/material/Box'
import Grid from '@mui/material/Grid'
import LockOutlinedIcon from '@mui/icons-material/LockOutlined'
import Typography from '@mui/material/Typography'
import { createTheme, ThemeProvider } from '@mui/material/styles'
import { CreateTodoListRequest } from '../../../../generated/api'
import { useFieldArray, UseFormReturn, Controller } from 'react-hook-form'

const theme = createTheme()

interface Props {
  form: UseFormReturn<CreateTodoListRequest>
  onSubmit: (data: CreateTodoListRequest) => any
}

export default function TodoFormView({ form, onSubmit }: Props) {
  const { register, formState, handleSubmit, control } = form
  const { fields, append, remove } = useFieldArray({
    control,
    name: 'items',
  })

  return (
    <ThemeProvider theme={theme}>
      <Grid container component="main" sx={{ height: '100vh', width: '100vw' }}>
        <CssBaseline />
        <Grid item xs={false} sm={4} md={7} />
        <Grid item xs={12} sm={8} md={5} component={Paper} elevation={6} square>
          <Box
            sx={{
              my: 8,
              mx: 4,
              display: 'flex',
              flexDirection: 'column',
              alignItems: 'center',
            }}
          >
            <Avatar sx={{ m: 1, bgcolor: 'secondary.main' }}>
              <LockOutlinedIcon />
            </Avatar>
            <Typography component="h1" variant="h5">
              Todo
            </Typography>
            <Box component="form" noValidate onSubmit={handleSubmit(onSubmit)} sx={{ mt: 1 }}>
              <TextField
                margin="normal"
                required
                fullWidth
                label="List name"
                autoComplete="email"
                autoFocus
                {...register('listName')}
                error={!!formState?.errors?.listName}
                helperText={formState?.errors?.listName?.message}
              />

              <Grid container>
                <Grid item>
                  <ul>
                    {fields.map((item, index) => (
                      <li key={item.id}>
                        <TextField
                          margin="normal"
                          required
                          fullWidth
                          label="body"
                          autoComplete="body"
                          {...register(`items.${index}.body`)}
                          error={!!formState?.errors?.items && !!formState?.errors?.items[index]?.body}
                          helperText={!!formState?.errors?.items && formState?.errors?.items[index]?.body?.message}
                        />
                        <TextField
                          margin="normal"
                          required
                          fullWidth
                          label="Headline"
                          autoComplete="headline"
                          {...register(`items.${index}.headline`)}
                          error={!!formState?.errors?.items && !!formState?.errors?.items[index]?.headline}
                          helperText={!!formState?.errors?.items && formState?.errors?.items[index]?.headline?.message}
                        />
                        <button type="button" onClick={() => remove(index)}>
                          Delete
                        </button>
                      </li>
                    ))}
                  </ul>
                  <Button
                    onClick={() => append({ body: '', headline: '' })}
                    fullWidth
                    variant="contained"
                    sx={{ mt: 3, mb: 2 }}
                  >
                    Add
                  </Button>
                </Grid>
              </Grid>

              <Button type="submit" fullWidth variant="contained" sx={{ mt: 3, mb: 2 }}>
                Create
              </Button>
            </Box>
          </Box>
        </Grid>
      </Grid>
    </ThemeProvider>
  )
}
