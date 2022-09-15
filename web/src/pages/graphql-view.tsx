import React, { useEffect } from 'react'
import { gql, useQuery } from 'urql'
import { SingleBigQueryQuery, TodoItemRequest } from '../../../generated/api'
import { useForm } from 'react-hook-form'
import CodeFlask from 'codeflasknextjs'
import { formatSdl } from 'format-graphql'

const SingleBigQuery = gql`
  query SingleBigQuery {
    allActors(first: 2) {
      nodes {
        actorId
        firstName
        lastName
        filmActorsByActorId(first: 1) {
          nodes {
            filmId
            filmByFilmId {
              description
              fulltext
            }
            lastUpdate
          }
        }
      }
    }
    allCustomers(first: 20) {
      nodes {
        addressByAddressId {
          address
          address2
        }
        createDate
        paymentsByCustomerId(first: 1) {
          nodes {
            amount
            paymentDate
          }
        }
      }
    }
  }
`

export function GraphqlView() {
  const {
    register,
    formState: { errors },
  } = useForm<TodoItemRequest & { listName: string }>()

  const [resultGql, queryTrigger] = useQuery<SingleBigQueryQuery>({
    query: SingleBigQuery,
    pause: true,
  })
  const { data: dataGql, fetching, error } = resultGql

  const fetchData = () => {
    queryTrigger({
      requestPolicy: 'network-only',
    })
  }

  useEffect(() => {
    const flask = new CodeFlask('.editor', { language: 'json', lineNumbers: true })
    if (dataGql) {
      flask.updateCode(JSON.stringify(dataGql, null, 2))
    } else {
      flask.updateCode(formatSdl(SingleBigQuery.loc?.source.body!))
    }
  }, [dataGql])

  if (fetching) return <p>Loading...</p>
  if (error) return <p>Oh no... {error.message}</p>

  return (
    <div>
      <div style={{ padding: '1 rem' }}>
        <h2>View db data</h2>
        <form>
          <div>{errors.listName && errors.listName.message}</div>
          <button onClick={fetchData} type="button">
            Fetch
          </button>
        </form>
        <h3>Latest</h3>
        <div className="editor" />
      </div>
    </div>
  )
}
