import ProfileForm from '~~/dapp/components/ProfileForm'
import NetworkSupportChecker from './components/NetworkSupportChecker'

export default function Home() {
  return (
    <>
      <NetworkSupportChecker />
      <div className="justify-content flex flex-grow flex-col items-center justify-center rounded-md p-3">
        <ProfileForm />
      </div>
    </>
  )
}
