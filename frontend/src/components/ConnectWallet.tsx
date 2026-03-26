import { useState, useEffect } from "react";
import { isConnected, setAllowed, getPublicKey, isAllowed } from "@stellar/freighter-api";
import { Wallet } from "lucide-react";

export const ConnectWallet = () => {
  const [address, setAddress] = useState<string | null>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    const checkConnection = async () => {
      try {
        if (await isConnected() && await isAllowed()) {
           const pk = await getPublicKey();
           setAddress(pk);
        }
      } catch (error) {
        console.error("Freighter check error:", error);
      } finally {
        setLoading(false);
      }
    };
    checkConnection();
  }, []);

  const connectWallet = async () => {
    try {
      if (await isConnected()) {
        await setAllowed();
        const pk = await getPublicKey();
        setAddress(pk);
      } else {
        alert("¡Por favor instala la extensión de Freighter en tu navegador!");
        window.open("https://freighter.app", "_blank");
      }
    } catch (error) {
      console.error("Error connecting wallet:", error);
    }
  };

  if (loading) return null;

  return (
    <button
      onClick={address ? () => {} : connectWallet}
      className={`flex items-center gap-2 px-4 py-2 text-sm font-bold rounded-lg transition-all border shadow-sm cursor-pointer
        ${address 
          ? "bg-purple-600 border-purple-800 text-white hover:bg-purple-700" 
          : "bg-white text-primary border-primary/20 hover:bg-gray-50"}`
      }
    >
      <Wallet className="w-4 h-4" />
      <span>
        {address 
          ? `${address.slice(0,4)}...${address.slice(-4)}` 
          : "Connect Wallet"}
      </span>
    </button>
  );
};
