import NetworkSupportChecker from './components/NetworkSupportChecker'
import GreetingForm from './dapp/components/GreetingForm'
import Image from 'next/image'

export default function Home() {
  return (
    <>
      <NetworkSupportChecker />
      <div className="flex flex-grow flex-col items-center justify-center rounded-md p-3 max-w-6xl mx-auto">
        {/* Hero Section */}
        <div className="text-center mb-12">
          <h1 className="bg-gradient-to-r from-sds-blue to-sds-pink bg-clip-text text-5xl font-bold !leading-tight text-transparent mb-4">
            AMOCA: Alliance Modeling Of Climate Action Finance
          </h1>
          <p className="text-lg mb-6">
            Harnessing the Sui ecosystem to revolutionize climate finance and accelerate global sustainability.
          </p>
        </div>

        {/* Main Content */}
        <div className="grid md:grid-cols-2 gap-8 mb-12">
          <div className="flex flex-col justify-center">
            <p className="mb-4">
              Climate change demands urgent action, but financial barriers often impede progress. AMOCA bridges this gap by creating a decentralized alliance where capital meets innovation. Built on the Sui blockchain, our platform transforms how climate initiatives are funded, tracked, and scaled.
            </p>
            <p>
              AMOCA unites governments, international organizations, private investors, and climate innovators in a transparent ecosystem powered by Web3 technology.
            </p>
          </div>
          <div className="rounded-lg overflow-hidden shadow-lg bg-gradient-to-br from-sds-blue/10 to-sds-pink/10 p-6">
            <h2 className="text-2xl font-bold mb-4 text-center">Our Platform Enables</h2>
            <ul className="space-y-3">
              <li className="flex items-start">
                <div className="mr-2 mt-1 text-sds-blue">•</div>
                <span><strong>Data-Driven Decision Making:</strong> Advanced modeling of climate initiatives providing clear insights into project feasibility and impact metrics</span>
              </li>
              <li className="flex items-start">
                <div className="mr-2 mt-1 text-sds-blue">•</div>
                <span><strong>Decentralized Funding Mechanisms:</strong> Streamlined investment flows with verifiable accountability through Sui's powerful object model</span>
              </li>
              <li className="flex items-start">
                <div className="mr-2 mt-1 text-sds-blue">•</div>
                <span><strong>Global Accessibility:</strong> Democratized access to climate financing for developing nations and grassroots innovators</span>
              </li>
              <li className="flex items-start">
                <div className="mr-2 mt-1 text-sds-blue">•</div>
                <span><strong>Transparent Impact Tracking:</strong> Real-time monitoring of project outcomes with blockchain-verified reporting</span>
              </li>
            </ul>
          </div>
        </div>

        {/* Call to Action */}
        <div className="text-center mb-12">
          <p className="text-lg mb-6">
            By leveraging Sui's secure, scalable infrastructure, AMOCA transforms climate action from aspiration to implementation—creating a financially sustainable path toward a climate-resilient future.
          </p>
          <div className="mt-8">
            <GreetingForm />
          </div>
        </div>
      </div>
    </>
  )
}
